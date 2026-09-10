/**
 * International E.164 Standard Phone Number Formatter
 * Strictly adheres to Twilio SMS dispatch standards and Nigerian (+234) mobile sanitization rules.
 */
export function formatToE164(phone: string, defaultCountryCode: string = '+234'): string {
  if (!phone || typeof phone !== 'string') {
    throw new Error('Phone number is required.');
  }

  // 1. Remove all spaces, dashes, parentheses, special characters except leading '+'
  let cleaned = phone.replace(/[^\d+]/g, '');

  // 2. Handle Nigerian local format (080..., 070..., 090...) and missing plus prefixes
  if (cleaned.startsWith('0')) {
    cleaned = defaultCountryCode + cleaned.substring(1);
  } else if (!cleaned.startsWith('+')) {
    if (cleaned.startsWith('234')) {
      cleaned = '+' + cleaned;
    } else {
      cleaned = defaultCountryCode + cleaned;
    }
  }

  // 3. E.164 regex check: starts with +, followed by 8 to 15 digits
  const e164Regex = /^\+[1-9]\d{7,14}$/;
  if (!e164Regex.test(cleaned)) {
    throw new Error(`Invalid E.164 mobile number format: ${phone}`);
  }

  // 4. Nigerian Mobile Number Rule (+234):
  // Nigerian mobile numbers must have exactly 10 digits after +234 (total length 14: +234XXXXXXXXXX)
  if (cleaned.startsWith('+234')) {
    if (cleaned.length !== 14) {
      throw new Error(
        `Invalid Nigerian mobile number length: ${phone}. Expected exactly 10 digits after +234 (e.g. +2348012345678 or 08012345678).`
      );
    }
  }

  return cleaned;
}
