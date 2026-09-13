/// Group E2E is not implemented. libsignal_protocol_dart is 1-to-1 Signal
/// (X3DH + Double Ratchet). There is no maintained MLS / Sender Keys package
/// in this project, and Seyra does not invent a group ratchet.
///
/// The backend may store opaque `e2e=true` bodies for groups (excluded from
/// plaintext search) for a future protocol. The Flutter client never sets
/// `e2e` on group or channel messages.
final class GroupE2ePolicy {
  static const bool supported = false;

  static const String limitation =
      'Group encryption requires a maintained group protocol (MLS or Signal Sender Keys). '
      'Seyra does not implement a homemade group Double Ratchet.';
}
