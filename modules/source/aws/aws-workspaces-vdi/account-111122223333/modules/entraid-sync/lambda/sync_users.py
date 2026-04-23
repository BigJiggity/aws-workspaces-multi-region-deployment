"""
Entra ID to AWS Managed AD User Sync

This Lambda function syncs users from Microsoft Entra ID (Azure AD) to AWS Managed AD.
It uses Microsoft Graph API to read users and LDAP to create them in Managed AD.

Environment Variables:
    ENTRA_SECRET_ARN: ARN of secret containing Entra ID credentials
    AD_SECRET_ARN: ARN of secret containing AD admin credentials
    DIRECTORY_ID: AWS Managed AD Directory ID
    DOMAIN_NAME: AD domain name (e.g., corp.example.internal)
    ENTRA_GROUP_FILTER: Optional - Entra ID group to filter users
    DEFAULT_OU: Optional - Default OU for new users
    AD_DNS_IPS: Comma-separated AD DNS IPs
"""

import os
import json
import logging
import secrets
import string
import boto3
from botocore.exceptions import ClientError

# Third-party imports (from Lambda layer)
import requests
from ldap3 import Server, Connection, ALL, NTLM, MODIFY_REPLACE

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
secrets_manager = boto3.client('secretsmanager')
ds_client = boto3.client('ds')


def get_secret(secret_arn: str) -> dict:
    """Retrieve secret from AWS Secrets Manager"""
    try:
        response = secrets_manager.get_secret_value(SecretId=secret_arn)
        return json.loads(response['SecretString'])
    except ClientError as e:
        logger.error(f"Failed to retrieve secret {secret_arn}: {e}")
        raise


def get_entra_access_token(tenant_id: str, client_id: str, client_secret: str) -> str:
    """Get OAuth2 access token from Microsoft Entra ID"""
    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    
    data = {
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret,
        'scope': 'https://graph.microsoft.com/.default'
    }
    
    response = requests.post(token_url, data=data)
    response.raise_for_status()
    
    return response.json()['access_token']


def get_entra_users(access_token: str, group_filter: str = None) -> list:
    """
    Fetch users from Microsoft Entra ID using Graph API
    
    Args:
        access_token: OAuth2 access token
        group_filter: Optional group name to filter users
    
    Returns:
        List of user dictionaries
    """
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    users = []
    
    if group_filter:
        # First, find the group
        group_url = f"https://graph.microsoft.com/v1.0/groups?$filter=displayName eq '{group_filter}'"
        response = requests.get(group_url, headers=headers)
        response.raise_for_status()
        groups = response.json().get('value', [])
        
        if not groups:
            logger.warning(f"Group '{group_filter}' not found in Entra ID")
            return []
        
        group_id = groups[0]['id']
        
        # Get members of the group
        members_url = f"https://graph.microsoft.com/v1.0/groups/{group_id}/members"
        while members_url:
            response = requests.get(members_url, headers=headers)
            response.raise_for_status()
            data = response.json()
            
            # Filter for user objects only
            for member in data.get('value', []):
                if member.get('@odata.type') == '#microsoft.graph.user':
                    users.append(member)
            
            members_url = data.get('@odata.nextLink')
    else:
        # Get all users
        users_url = "https://graph.microsoft.com/v1.0/users?$select=id,userPrincipalName,displayName,givenName,surname,mail,accountEnabled,jobTitle,department,officeLocation,mobilePhone,businessPhones"
        
        while users_url:
            response = requests.get(users_url, headers=headers)
            response.raise_for_status()
            data = response.json()
            users.extend(data.get('value', []))
            users_url = data.get('@odata.nextLink')
    
    logger.info(f"Retrieved {len(users)} users from Entra ID")
    return users


def generate_password(length: int = 16) -> str:
    """Generate a secure random password that meets AD complexity requirements"""
    # Ensure password meets complexity: uppercase, lowercase, digit, special
    uppercase = secrets.choice(string.ascii_uppercase)
    lowercase = secrets.choice(string.ascii_lowercase)
    digit = secrets.choice(string.digits)
    special = secrets.choice('!@#$%^&*()_+-=[]{}|')
    
    # Fill the rest with random characters
    remaining_length = length - 4
    all_chars = string.ascii_letters + string.digits + '!@#$%^&*()_+-=[]{}|'
    remaining = ''.join(secrets.choice(all_chars) for _ in range(remaining_length))
    
    # Shuffle all characters
    password_list = list(uppercase + lowercase + digit + special + remaining)
    secrets.SystemRandom().shuffle(password_list)
    
    return ''.join(password_list)


def connect_to_ad(ad_dns_ip: str, domain: str, username: str, password: str) -> Connection:
    """
    Establish LDAP connection to AWS Managed AD
    
    Args:
        ad_dns_ip: IP address of AD domain controller
        domain: AD domain name (e.g., corp.example.internal)
        username: AD admin username
        password: AD admin password
    
    Returns:
        LDAP Connection object
    """
    server = Server(ad_dns_ip, get_info=ALL, use_ssl=False)
    
    # Format: DOMAIN\username for NTLM authentication
    netbios_domain = domain.split('.')[0].upper()
    ntlm_user = f"{netbios_domain}\\{username}"
    
    conn = Connection(
        server,
        user=ntlm_user,
        password=password,
        authentication=NTLM,
        auto_bind=True
    )
    
    logger.info(f"Connected to AD at {ad_dns_ip}")
    return conn


def get_domain_dn(domain: str) -> str:
    """Convert domain name to distinguished name (e.g., corp.example.internal -> DC=corp,DC=example,DC=internal)"""
    return ','.join([f'DC={part}' for part in domain.split('.')])


def user_exists_in_ad(conn: Connection, domain_dn: str, sam_account_name: str) -> bool:
    """Check if user already exists in AD"""
    search_filter = f'(sAMAccountName={sam_account_name})'
    conn.search(domain_dn, search_filter, attributes=['sAMAccountName'])
    return len(conn.entries) > 0


def extract_sam_account_name(upn: str) -> str:
    """
    Extract sAMAccountName from userPrincipalName
    
    Examples:
        john.doe@company.com -> john.doe
        jdoe@company.onmicrosoft.com -> jdoe
    """
    # Take the part before @ and truncate to 20 chars (AD limit)
    sam = upn.split('@')[0][:20]
    # Replace any invalid characters
    sam = ''.join(c if c.isalnum() or c in '.-_' else '_' for c in sam)
    return sam


def create_ad_user(conn: Connection, domain_dn: str, default_ou: str, user: dict, domain: str) -> dict:
    """
    Create a new user in AWS Managed AD
    
    Args:
        conn: LDAP connection
        domain_dn: Domain distinguished name
        default_ou: Default OU for new users
        user: User dictionary from Entra ID
        domain: AD domain name
    
    Returns:
        Dictionary with user info and generated password
    """
    upn = user.get('userPrincipalName', '')
    sam_account_name = extract_sam_account_name(upn)
    display_name = user.get('displayName', sam_account_name)
    given_name = user.get('givenName', '')
    surname = user.get('surname', '')
    email = user.get('mail', upn)
    
    # Determine OU - use default or Users container
    if default_ou:
        user_dn = f'CN={display_name},{default_ou}'
    else:
        # Default to Users container in Managed AD
        user_dn = f'CN={display_name},OU=Users,OU={domain.split(".")[0]},{domain_dn}'
    
    # Generate password
    password = generate_password()
    
    # User attributes
    user_attrs = {
        'objectClass': ['top', 'person', 'organizationalPerson', 'user'],
        'cn': display_name,
        'sAMAccountName': sam_account_name,
        'userPrincipalName': f'{sam_account_name}@{domain}',
        'displayName': display_name,
        'mail': email,
        'userAccountControl': '512',  # Normal account, enabled
    }
    
    if given_name:
        user_attrs['givenName'] = given_name
    if surname:
        user_attrs['sn'] = surname
    if user.get('jobTitle'):
        user_attrs['title'] = user['jobTitle']
    if user.get('department'):
        user_attrs['department'] = user['department']
    if user.get('officeLocation'):
        user_attrs['physicalDeliveryOfficeName'] = user['officeLocation']
    if user.get('mobilePhone'):
        user_attrs['mobile'] = user['mobilePhone']
    
    # Create the user
    success = conn.add(user_dn, attributes=user_attrs)
    
    if not success:
        logger.error(f"Failed to create user {sam_account_name}: {conn.result}")
        return None
    
    # Set the password (requires separate operation)
    # Password must be enclosed in quotes and encoded as UTF-16-LE
    password_value = f'"{password}"'.encode('utf-16-le')
    
    modify_success = conn.modify(
        user_dn,
        {'unicodePwd': [(MODIFY_REPLACE, [password_value])]}
    )
    
    if not modify_success:
        logger.warning(f"User {sam_account_name} created but password set failed: {conn.result}")
    
    logger.info(f"Created AD user: {sam_account_name}")
    
    return {
        'sam_account_name': sam_account_name,
        'user_principal_name': f'{sam_account_name}@{domain}',
        'display_name': display_name,
        'email': email,
        'password': password,
        'entra_id': user.get('id'),
        'entra_upn': upn
    }


def update_ad_user(conn: Connection, domain_dn: str, sam_account_name: str, user: dict) -> bool:
    """
    Update existing AD user with latest Entra ID attributes
    
    Args:
        conn: LDAP connection
        domain_dn: Domain distinguished name
        sam_account_name: AD sAMAccountName
        user: User dictionary from Entra ID
    
    Returns:
        True if update successful
    """
    # Find the user
    search_filter = f'(sAMAccountName={sam_account_name})'
    conn.search(domain_dn, search_filter, attributes=['distinguishedName'])
    
    if not conn.entries:
        logger.warning(f"User {sam_account_name} not found for update")
        return False
    
    user_dn = conn.entries[0].distinguishedName.value
    
    # Build modifications
    modifications = {}
    
    if user.get('displayName'):
        modifications['displayName'] = [(MODIFY_REPLACE, [user['displayName']])]
    if user.get('givenName'):
        modifications['givenName'] = [(MODIFY_REPLACE, [user['givenName']])]
    if user.get('surname'):
        modifications['sn'] = [(MODIFY_REPLACE, [user['surname']])]
    if user.get('mail'):
        modifications['mail'] = [(MODIFY_REPLACE, [user['mail']])]
    if user.get('jobTitle'):
        modifications['title'] = [(MODIFY_REPLACE, [user['jobTitle']])]
    if user.get('department'):
        modifications['department'] = [(MODIFY_REPLACE, [user['department']])]
    
    if modifications:
        success = conn.modify(user_dn, modifications)
        if success:
            logger.info(f"Updated AD user: {sam_account_name}")
        else:
            logger.warning(f"Failed to update {sam_account_name}: {conn.result}")
        return success
    
    return True


def store_user_credentials(user_info: dict) -> None:
    """
    Store newly created user credentials in Secrets Manager
    This allows admins to retrieve initial passwords for users
    """
    secret_name = f"org-workspaces-vdi/users/{user_info['sam_account_name']}"
    
    try:
        secrets_manager.create_secret(
            Name=secret_name,
            Description=f"Initial credentials for {user_info['display_name']}",
            SecretString=json.dumps({
                'username': user_info['sam_account_name'],
                'password': user_info['password'],
                'email': user_info['email'],
                'entra_upn': user_info['entra_upn'],
                'created_by': 'entraid-sync'
            })
        )
        logger.info(f"Stored credentials for {user_info['sam_account_name']} in Secrets Manager")
    except secrets_manager.exceptions.ResourceExistsException:
        # Update existing secret with new password
        secrets_manager.put_secret_value(
            SecretId=secret_name,
            SecretString=json.dumps({
                'username': user_info['sam_account_name'],
                'password': user_info['password'],
                'email': user_info['email'],
                'entra_upn': user_info['entra_upn'],
                'created_by': 'entraid-sync'
            })
        )
        logger.info(f"Updated credentials for {user_info['sam_account_name']} in Secrets Manager")


def lambda_handler(event, context):
    """
    Main Lambda handler - syncs users from Entra ID to AWS Managed AD
    """
    logger.info("Starting Entra ID to Managed AD sync")
    
    # Get configuration from environment
    entra_secret_arn = os.environ['ENTRA_SECRET_ARN']
    ad_secret_arn = os.environ['AD_SECRET_ARN']
    directory_id = os.environ['DIRECTORY_ID']
    domain_name = os.environ['DOMAIN_NAME']
    group_filter = os.environ.get('ENTRA_GROUP_FILTER', '')
    default_ou = os.environ.get('DEFAULT_OU', '')
    ad_dns_ips = os.environ.get('AD_DNS_IPS', '').split(',')
    
    # Get credentials
    entra_creds = get_secret(entra_secret_arn)
    ad_creds = get_secret(ad_secret_arn)
    
    # Get Entra ID access token
    access_token = get_entra_access_token(
        entra_creds['tenant_id'],
        entra_creds['client_id'],
        entra_creds['client_secret']
    )
    
    # Fetch users from Entra ID
    entra_users = get_entra_users(access_token, group_filter if group_filter else None)
    
    if not entra_users:
        logger.info("No users found in Entra ID to sync")
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'No users to sync', 'synced': 0, 'updated': 0})
        }
    
    # Connect to AD
    ad_conn = None
    for dns_ip in ad_dns_ips:
        try:
            ad_conn = connect_to_ad(
                dns_ip.strip(),
                domain_name,
                ad_creds['username'],
                ad_creds['password']
            )
            break
        except Exception as e:
            logger.warning(f"Failed to connect to AD at {dns_ip}: {e}")
            continue
    
    if not ad_conn:
        raise Exception("Failed to connect to any AD domain controller")
    
    domain_dn = get_domain_dn(domain_name)
    
    # Sync users
    created_count = 0
    updated_count = 0
    skipped_count = 0
    errors = []
    
    for user in entra_users:
        try:
            # Skip disabled users
            if not user.get('accountEnabled', True):
                logger.info(f"Skipping disabled user: {user.get('userPrincipalName')}")
                skipped_count += 1
                continue
            
            upn = user.get('userPrincipalName', '')
            if not upn:
                logger.warning(f"Skipping user without UPN: {user.get('id')}")
                skipped_count += 1
                continue
            
            sam_account_name = extract_sam_account_name(upn)
            
            if user_exists_in_ad(ad_conn, domain_dn, sam_account_name):
                # Update existing user
                if update_ad_user(ad_conn, domain_dn, sam_account_name, user):
                    updated_count += 1
            else:
                # Create new user
                user_info = create_ad_user(ad_conn, domain_dn, default_ou, user, domain_name)
                if user_info:
                    store_user_credentials(user_info)
                    created_count += 1
                else:
                    errors.append(f"Failed to create {sam_account_name}")
                    
        except Exception as e:
            logger.error(f"Error processing user {user.get('userPrincipalName')}: {e}")
            errors.append(str(e))
    
    # Close AD connection
    ad_conn.unbind()
    
    result = {
        'message': 'Sync completed',
        'created': created_count,
        'updated': updated_count,
        'skipped': skipped_count,
        'errors': len(errors)
    }
    
    logger.info(f"Sync complete: {result}")
    
    if errors:
        logger.error(f"Errors encountered: {errors[:10]}")  # Log first 10 errors
    
    return {
        'statusCode': 200,
        'body': json.dumps(result)
    }
