# Create Keystore for Play Store Publishing

## Step 1: Generate the keystore

Run this command to create a new keystore (replace the values as needed):

```bash
keytool -genkey -v -keystore ~/hymns-mobile-upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

You will be prompted to enter:
- Keystore password (remember this!)
- Key password (can be same as keystore password)
- Your name/organization details

## Step 2: Create key.properties file

Copy the template:
```bash
cp key.properties.template key.properties
```

Edit key.properties with your actual values:
```
storePassword=YOUR_ACTUAL_PASSWORD
keyPassword=YOUR_ACTUAL_PASSWORD
keyAlias=upload
storeFile=/Users/YOUR_USERNAME/hymns-mobile-upload-keystore.jks
```

**IMPORTANT**: 
- Never commit key.properties to git (already in .gitignore)
- Store your keystore file and passwords securely
- If you lose the keystore, you cannot update the app on Play Store!

## Step 3: Verify .gitignore

Make sure these are in your .gitignore:
```
/android/key.properties
*.jks
*.keystore
```
