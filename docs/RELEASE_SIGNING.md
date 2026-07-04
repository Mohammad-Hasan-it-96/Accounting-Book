# Release Signing — Upload Keystore Setup

This is the one-time setup that resolves **C1** (the release build refuses to sign
until it exists). After this, `flutter build appbundle --release` produces a
Play-uploadable, correctly-signed `.aab`.

> **How the build uses it:** `android/app/build.gradle.kts` reads
> `android/key.properties`. If that file is **absent**, a *release* build
> (`assemble*Release` / `bundle*Release` / `package*Release`) **fails with a clear
> error** instead of silently signing with the debug key. Debug builds are
> unaffected.

The build needs exactly four properties: `keyAlias`, `keyPassword`, `storeFile`,
`storePassword`.

---

## 0. Prerequisites

`keytool` ships with the JDK. On this machine it is at:

```
C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe
```

Everything below is written for **PowerShell** on Windows.

---

## 1. Generate the upload keystore

Store the keystore **outside the repository** so it can never be committed. Create
a keys folder and generate a 2048-bit RSA key valid for ~27 years (Google requires
validity well past 2033):

```powershell
# Create a safe location outside the project
New-Item -ItemType Directory -Force "$HOME\keys" | Out-Null

# Generate the keystore (you'll be prompted for passwords + a distinguished name)
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" `
  -genkeypair -v `
  -keystore "$HOME\keys\daftar-upload.jks" `
  -alias daftar-upload `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -storetype PKCS12
```

When prompted:
- **Keystore password** — choose a strong password; you'll reuse it as
  `storePassword`.
- **Key password** — press Enter to reuse the keystore password (simplest), or set
  a distinct one (that becomes `keyPassword`).
- **Distinguished name** (name/org/city/country) — used only inside the cert; any
  accurate values are fine (e.g. CN = your name/company, C = your 2-letter country
  code).

This creates `C:\Users\<you>\keys\daftar-upload.jks` with alias `daftar-upload`.

---

## 2. Create `android/key.properties`

Create the file `android/key.properties` (it is **gitignored** — never commit it):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=daftar-upload
storeFile=C:/Users/YOUR_USER/keys/daftar-upload.jks
```

> **Path gotcha:** `key.properties` is a Java properties file, so **backslashes are
> escape characters**. Use **forward slashes** in `storeFile` (as above), or double
> every backslash (`C:\\Users\\...`). If you set the key password to the same value
> as the keystore password in step 1, set `keyPassword` to that same value.

---

## 3. Confirm it will never be committed

These are already in `.gitignore` (verify):

```
android/key.properties
android/release.jks
*.jks
```

`*.jks` covers the keystore wherever it lives; `key.properties` is covered by the
first line. Quick check — this must print **nothing**:

```powershell
git status --porcelain | Select-String -Pattern 'key.properties|\.jks'
```

---

## 4. Build and verify the signed release

```powershell
flutter build appbundle --release
```

Expected output ends with:

```
√ Built build\app\outputs\bundle\release\app-release.aab
```

**Negative check (proves C1 works):** temporarily rename `android/key.properties`
and rebuild — the build should **fail** with
`التوقيع للإصدار غير مُهيّأ ...` ("release signing is not configured"). Restore the
file afterward.

**Confirm the signature** on the built bundle:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" `
  -printcert -jarfile "build\app\outputs\bundle\release\app-release.aab"
```

It should print the certificate you just created (SHA-256 fingerprint, validity).

---

## 5. Back up the keystore — this is critical

If you lose `daftar-upload.jks` **or** its passwords, you can **never publish an
update** to the same app listing (short of Google's key-reset process). Do all of:

- Copy `daftar-upload.jks` to **at least two** secure, offline locations (encrypted
  USB, password manager attachment, private cloud vault).
- Store the **keystore password**, **key password**, and **alias** in your password
  manager.
- Do **not** email it to yourself or drop it in the repo.

---

## 6. Google Play App Signing (context you need once)

When you first upload the `.aab`, enrol in **Play App Signing** (default). Then:
- The key you just made is your **upload key** — it only proves uploads are from
  you. Google re-signs the app with a separate **app signing key** it manages.
- If you ever lose the upload key, Google **can** reset it (unlike the app signing
  key). Still treat it as critical.
- Grab the **SHA-1 / SHA-256** from Play Console → *App integrity* if you later add
  services that need them (Maps, Sign-in, App Links, etc.).

---

## 7. (Optional) CI / GitHub Actions signing

To sign in CI without committing secrets, base64-encode the keystore into a secret
and reconstruct it at build time:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\keys\daftar-upload.jks")) `
  | Set-Content -NoNewline keystore.b64
```

Add repository secrets: `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`,
`KEY_ALIAS`. In the workflow, decode `KEYSTORE_BASE64` back to a `.jks` and write
`android/key.properties` from the secrets before `flutter build appbundle`.

---

## Checklist

- [ ] Keystore generated at `~\keys\daftar-upload.jks` (outside the repo)
- [ ] `android/key.properties` created with the four keys + forward-slash path
- [ ] `git status` shows neither the keystore nor `key.properties`
- [ ] `flutter build appbundle --release` succeeds
- [ ] Rename-away negative test fails as expected, then restored
- [ ] `-printcert -jarfile` shows the expected certificate
- [ ] Keystore + passwords backed up in ≥2 secure places
