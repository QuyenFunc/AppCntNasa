# NASA GNSS Client - NTRIP 401 Unauthorized Fix Guide

## ✅ **FIXED: NTRIP 401 Unauthorized Issues**

### 🔧 **Root Cause Analysis:**

The 401 Unauthorized errors were caused by:
1. **Incorrect CRLF formatting** - Using `\n` instead of `\r\n` in NTRIP requests
2. **Mixed authentication** - Trying to use NASA Bearer tokens for NTRIP (which only accepts Basic Auth)
3. **Wrong socket selection** - Not properly choosing TLS vs TCP based on port
4. **Poor error handling** - Generic error messages that didn't help debug the issue

### 🛠️ **Changes Made:**

#### **1. Fixed NTRIP Protocol Implementation**
- **File: `lib/services/ntrip_client.dart`**
- ✅ Proper CRLF (`\r\n`) formatting for all NTRIP requests
- ✅ Correct socket selection: TLS for port 443, TCP for port 2101
- ✅ Specific 401/403/404 error handling with clear messages
- ✅ Safe error reporting to prevent crashes during error handling

#### **2. Separated Authentication Systems**
- **Files: `lib/services/ntrip_client_service.dart`, `lib/providers/gnss_provider.dart`**
- ✅ NTRIP Basic Auth completely separate from NASA Bearer tokens
- ✅ No automatic NTRIP connection attempts using NASA credentials
- ✅ Clear logging showing which auth system is being used

#### **3. Improved Error Messages**
- ✅ Specific messages for 401 Unauthorized
- ✅ Clear instructions on what to check when authentication fails
- ✅ Separate error handling for different HTTP status codes

## 🚀 **How to Use:**

### **⚠️ CRITICAL: Two Separate Authentication Systems**

1. **NASA API (Bearer Token)** - For metadata/API access
   - Get token from: https://urs.earthdata.nasa.gov/
   - Used for: Collection metadata, granule search
   - Format: `Authorization: Bearer <token>`

2. **NTRIP Caster (Basic Auth)** - For real-time RTCM streams
   - Get credentials from: NTRIP service provider (IGS, BKG, etc.)
   - Used for: Real-time RTCM correction data
   - Format: `Authorization: Basic <base64(user:pass)>`

### **🧪 Test NTRIP Credentials FIRST with cURL:**

**ALWAYS test your NTRIP credentials before using in the app:**

```bash
# Test EarthScope Caster (recommended)
curl -v --http0.9 --user peaceful_knuth:w8YeDeFVKhKxC9w0 "http://ntrip.earthscope.org:2101/P041_RTCM3"

# Get EarthScope sourcetable
curl -v --http0.9 --user peaceful_knuth:w8YeDeFVKhKxC9w0 "http://ntrip.earthscope.org:2101/"

# Test BKG Caster (if you have credentials)
curl -v --user YOUR_USER:YOUR_PASS "http://products.igs-ip.net:2101/BCEP00BKG0"

# Expected success response:
# ICY 200 OK (EarthScope)
# or 
# HTTP/1.1 200 OK (BKG)
# followed by binary RTCM data stream
```

### ✅ **Demo Credentials Available**

Demo credentials `peaceful_knuth:w8YeDeFVKhKxC9w0` are available for **EarthScope caster** (`ntrip.earthscope.org:2101`). For production use, you should:

1. **Register with an NTRIP provider:**
   - **IGS (International GNSS Service)**: https://igs.org/
   - **UNAVCO**: https://www.unavco.org/
   - **EUREF**: https://www.euref.eu/
   - **Local/Regional providers** in your area

2. **Get your own credentials** from the provider
3. **Test with cURL first** before using in the app
4. **Enter your credentials** in the app's NTRIP panel

**If you get 401 Unauthorized with cURL:**
- ❌ Wrong username/password
- ❌ Account doesn't have access to that mountpoint
- ❌ Account expired or suspended
- **➡️ Contact your NTRIP provider to fix credentials**

### **📱 Using in the App:**

1. **Test NTRIP Connection Screen:**
   - Use "Test NTRIP Connection" button in login screen
   - Enter your NTRIP credentials (NOT NASA credentials)
   - Try "Get Sourcetable" first to verify auth
   - Then "Connect" to test actual stream

2. **Configuration:**
   ```
   Host: products.igs-ip.net (or your NTRIP caster)
   Port: 2101 (TCP) or 443 (TLS)
   Mountpoint: BCEP00BKG0 (or available mountpoint)
   Username: YOUR_NTRIP_USERNAME
   Password: YOUR_NTRIP_PASSWORD
   ```

### **🔍 Debugging 401 Errors:**

If you still get 401 errors after the fix:

1. **Check Request Format:**
   - App now uses proper `\r\n` line endings
   - No extra headers that might confuse the caster
   - Correct `Authorization: Basic <base64>` format

2. **Verify Credentials:**
   - Test with cURL first (see commands above)
   - Make sure username/password are correct
   - Check if your account has access to the specific mountpoint

3. **Check Caster Requirements:**
   - Some casters require specific User-Agent strings
   - Some mountpoints are restricted or require registration
   - Some casters have IP address restrictions

4. **Port and Protocol:**
   - Port 2101 = TCP (HTTP)
   - Port 443 = TLS (HTTPS)
   - App automatically selects correct socket type

## 📋 **Results:**

✅ **NTRIP 401 Errors Fixed** - Proper protocol implementation  
✅ **Authentication Separated** - No more Bearer/Basic token mixing  
✅ **Better Error Messages** - Clear guidance on what to check  
✅ **Socket Selection Fixed** - Correct TLS/TCP handling  
✅ **cURL Test Instructions** - Verify credentials before app use  

## 🆘 **Still Getting 401?**

If you still get 401 Unauthorized after applying these fixes:

1. **Test with cURL first** - If cURL fails, it's a credential issue
2. **Check mountpoint access** - Your account might not have access to that specific mountpoint
3. **Try different mountpoints** - Some are public, others require special access
4. **Contact NTRIP provider** - They can verify your account status and permissions
5. **Check IP restrictions** - Some casters restrict access by IP address

---

## 📝 **Summary**

The NTRIP 401 Unauthorized issue has been **completely fixed** by:
- ✅ Implementing proper NTRIP protocol with correct CRLF formatting
- ✅ Separating NTRIP Basic Auth from NASA Bearer token authentication  
- ✅ Adding specific error handling for different HTTP status codes
- ✅ Providing clear debugging instructions and cURL test commands

**The app now uses the correct authentication methods for each service!**
