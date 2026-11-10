// hlthstack PWA SSO: build the `message` and `auth_tag` form fields (Java 11+, JDK only).
//
// Run:  HLTHSTACK_ENCODED_KEY=... HLTHSTACK_ENCODED_IV=... HLTHSTACK_ENTITY_ID=... java HlthstackSso.java
// Prints {"message": "...", "auth_tag": "..."} as JSON.
//
// Build the payload JSON with your usual JSON library; it is a string literal here only to keep
// the example dependency-free.

import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

public class HlthstackSso {
    private static final int TAG_BYTES = 16;

    /** Returns {message, authTag}: URL-safe Base64 (with padding) ciphertext and GCM tag. */
    public static String[] buildSsoParams(String payloadJson, String encodedKey, String encodedIv) throws Exception {
        byte[] key = Base64.getMimeDecoder().decode(encodedKey);
        byte[] iv = Base64.getMimeDecoder().decode(encodedIv);
        if (key.length != 32) throw new IllegalArgumentException("encoded_key must decode to 32 bytes");

        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(TAG_BYTES * 8, iv));
        byte[] sealed = cipher.doFinal(payloadJson.getBytes(StandardCharsets.UTF_8)); // ciphertext || tag

        Base64.Encoder enc = Base64.getUrlEncoder();
        return new String[] {
            enc.encodeToString(Arrays.copyOfRange(sealed, 0, sealed.length - TAG_BYTES)),
            enc.encodeToString(Arrays.copyOfRange(sealed, sealed.length - TAG_BYTES, sealed.length))
        };
    }

    public static void main(String[] args) throws Exception {
        long requestedAt = System.currentTimeMillis() / 1000L; // Unix time in SECONDS, set right before launch
        String payload = "{\"entity_id\":\"" + System.getenv("HLTHSTACK_ENTITY_ID") + "\","
            + "\"email\":\"jane.doe@example.com\",\"member_id\":\"EMP-0001\","
            + "\"first_name\":\"Jane\",\"last_name\":\"Doe\",\"gender\":\"F\","
            + "\"deeplink\":\"benefits\",\"requested_at\":" + requestedAt + "}";
        String[] p = buildSsoParams(payload, System.getenv("HLTHSTACK_ENCODED_KEY"), System.getenv("HLTHSTACK_ENCODED_IV"));
        System.out.println("{\"message\":\"" + p[0] + "\",\"auth_tag\":\"" + p[1] + "\"}");
    }
}
