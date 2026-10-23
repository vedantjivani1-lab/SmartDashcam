import Foundation

/// Plain-text bodies shown in-app for the two full legal documents.
///
/// These mirror PRIVACY_POLICY.md and TERMS_OF_SERVICE.md — if you edit
/// the wording in one place, update the other so the in-app text and the
/// hosted web version (the one Apple requires a URL for) don't drift
/// apart.
enum LegalDocumentText {

    static let privacyPolicyLastUpdated = "17 October 2026"
    static let termsLastUpdated = "17 October 2026"

    static let privacyPolicy = """
    PRIVACY POLICY FOR FOCUS

    Last updated: \(privacyPolicyLastUpdated)

    This is the privacy policy for Focus, made by GEN-Z DIGITAL PRIVATE LIMITED, a private limited company incorporated in India (PAN: AANCG4242N). Using the app means your agreeing to whats below.

    1. WHAT WE COLLECT

    Video — records the road while its running, older clips get overwritten once you hit your storage limit, except crash clips which stay protected. No audio, just video.

    Location/speed — GPS shows your speed and location and also gets burned into the video itself, not just shown on screen.

    License plates — an optional feature reads plate text on-device using on-device machine learning. Doesn't leave your phone unless you turn cloud backup on separately. Comes with a confidence score since it can't always read clearly.

    Crash detection — motion sensors try to catch a crash. Not a certified detector, just a threshold, so it can miss real crashes or go off from a pot hole.

    Emergency contact — if you set one up we save there name/number on device to pre-fill a text after a crash is detected. You still have to hit send yourself.

    Cloud backup (optional) — if on, crash clips upload to your cloud provider. If off, nothing leaves the phone.

    Account — your name (which you enter) and your phone number, used to sign you in with a one-time code and to personalise the app, plus a unique account ID.

    Other — basic device info (model, OS version, crash logs) to help fix bugs.

    2. WHAT WE USE IT FOR

    Making the app work and fixing bugs. We don't sell your info.

    3. WHERE ITS STORED

    Everything stays on your phone unless cloud backup is turned on, then crash clips also go to your cloud provider.

    4. HOW LONG WE KEEP IT

    Loop footage auto-deletes past your storage limit (except protected crash clips). Delete a clip anytime. Uninstalling removes everything local.

    5. YOUR CHOICES AND DELETING YOUR ACCOUNT

    You can delete your account and all associated data at any time in the app: Settings → Account → Delete Account. This removes your account, cloud backups, and all footage, clips and settings stored on your device.

    Turn off Camera/Location/Motion in phone Settings anytime. Plate reading and cloud backup can be switched off in app Settings too.

    6. OTHER COMPANIES

    Cloud backup (if on) is handled by Firebase Storage / Google, check there policy too.

    7. KIDS

    Not meant for kids under 13, we don't knowingly collect there info.

    8. USING THIS RESPONSIBLY

    Recording and plate reading laws are different everywhere, its on you to use this legally where you are. Don't use the plate reader to stalk or spy on people.

    9. SECURITY

    We try to keep things safe but nothing's 100% secure.

    10. CHANGES

    We might update this sometime, date at top will change if we do.

    11. CONTACT

    genzdigitalprivatelimited@gmail.com

    """

    static let termsOfService = """
    TERMS OF SERVICE FOR FOCUS

    Last updated: \(termsLastUpdated)

    Using Focus means you agree to this. If you don't agree, don't use it.

    1. WHAT THE APP DOES

    Loop recording, speed/GPS overlay, crash detection, optional plate reader, optional emergency text, optional cloud backup.

    2. NOT A CERTIFIED SAFETY DEVICE

    Crash detection is a motion-sensor threshold thing, it can miss a real crash or false trigger off a bump. The emergency text needs YOU to hit send, the app can't send it on its own. Call your real emergency number if somethings actually urgent, don't rely on this app for that.

    3. LICENSE PLATE READER

    Only reads whats actually visible, shows a confidence score, doesn't guess characters it can't see. Double check low-confidence readings yourself before relying on them. You're responsible for using this legally and not for stalking or spying on anyone.

    4. YOUR RESPONSIBILITIES

    Use it legally where you drive, don't let it distract you, don't treat it as a replacement for safe driving/insurance/calling emergency services, whatever you record is on you.

    5. PERMISSIONS

    Camera + Location required, Motion used for crash detection. Turn any off in Settings and that feature stops.

    6. CLOUD BACKUP

    Its your own cloud account your connecting, so costs/terms from that provider are between you and them.

    7. WHO OWNS WHAT

    App belongs to GEN-Z DIGITAL PRIVATE LIMITED. You get a license for personal, non commercial use. Your video/data is yours.

    7A. ACCOUNT

    A free account is required. You can delete your account in the app under Settings → Account.

    8. NO WARRANTY

    Provided as is, no guarantee crash detection or plate reading is always accurate.

    9. LIMITATION OF LIABILITY

    GEN-Z DIGITAL PRIVATE LIMITED isn't liable for indirect damages from using the app, to the extent the law allows — including missed crash detection, delayed emergency text, or wrong plate readings.

    10. INDEMNIFICATION

    If you misuse the app and that gets us in trouble, you agree to cover us for it.

    11. ENDING THINGS

    We can change/shut down the app anytime, you can stop using it anytime too.

    12. CHANGES TO THESE TERMS

    Might update these sometime, date at top changes if we do.

    13. GOVERNING LAW

    India

    14. CONTACT

    genzdigitalprivatelimited@gmail.com

    Template only, not legal advice.
    """
}
