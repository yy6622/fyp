import 'package:cloud_firestore/cloud_firestore.dart';

/// One message inside an [InsuranceChatRepository] thread. A partner can
/// attach a specific plan instead of (or alongside) plain text —
/// [attachedPlanId] is then set and the UI renders a plan card; the live
/// plan itself is fetched on demand via InsuranceRepository.getPlan so the
/// card always shows the plan's current price/coverage rather than a
/// point-in-time copy (see sendInsuranceChatPlan in admin_web/js/data.js).
class InsuranceChatMessage {
  final String id;
  final String senderId;
  final String senderRole; // 'traveller' | 'partner'
  final String text;
  final String? attachedPlanId;
  final DateTime? createdAt;
  const InsuranceChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    this.attachedPlanId,
    this.createdAt,
  });
}

/// Summary of a chat thread, as seen from either side (traveller's own
/// list of partners they've messaged, or a partner's list of travellers).
class InsuranceChatSummary {
  final String id;
  final String travellerId;
  final String travellerName;
  final String partnerId;
  final String providerName;
  final String? planName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastSenderRole;
  final bool unreadForTraveller;
  final bool unreadForPartner;
  const InsuranceChatSummary({
    required this.id,
    required this.travellerId,
    required this.travellerName,
    required this.partnerId,
    required this.providerName,
    this.planName,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastSenderRole = '',
    this.unreadForTraveller = false,
    this.unreadForPartner = false,
  });
}

/// A direct-message thread between one traveller and one insurance
/// partner — deliberately not tied to a specific purchase, so a traveller
/// can message a partner with questions before buying a plan, as well as
/// to discuss an existing policy afterwards. One thread per
/// (traveller, partner) pair, keyed by a deterministic id so both sides
/// always land on the same thread without a lookup query.
class InsuranceChatRepository {
  InsuranceChatRepository._();
  static final InsuranceChatRepository instance = InsuranceChatRepository._();

  CollectionReference<Map<String, dynamic>> get _chats => FirebaseFirestore.instance.collection('insurance_chats');

  String chatIdFor({required String travellerId, required String partnerId}) => '${travellerId}_$partnerId';

  /// Creates the thread (if it doesn't exist yet) so it shows up in the
  /// partner's inbox even before either side has sent a message, and
  /// keeps the traveller/provider display names fresh on repeat visits.
  Future<String> ensureChat({
    required String travellerId,
    required String travellerName,
    required String partnerId,
    required String providerName,
    String? planName,
  }) async {
    final id = chatIdFor(travellerId: travellerId, partnerId: partnerId);
    await _chats.doc(id).set({
      'travellerId': travellerId,
      'travellerName': travellerName,
      'partnerId': partnerId,
      'providerName': providerName,
      if (planName != null && planName.isNotEmpty) 'planName': planName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return id;
  }

  Stream<List<InsuranceChatMessage>> watchMessages(String chatId) {
    return _chats.doc(chatId).collection('messages').orderBy('createdAt').snapshots().map((snap) => snap.docs
        .map((d) => InsuranceChatMessage(
              id: d.id,
              senderId: (d.data()['senderId'] as String?) ?? '',
              senderRole: (d.data()['senderRole'] as String?) ?? '',
              text: (d.data()['text'] as String?) ?? '',
              attachedPlanId: (d.data()['attachedPlanId'] as String?),
              createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate(),
            ))
        .toList());
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final chatRef = _chats.doc(chatId);
    await chatRef.collection('messages').add({
      'senderId': senderId,
      'senderRole': senderRole,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await chatRef.update({
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderRole': senderRole,
      // Whoever didn't just send it has something new to read.
      'unreadForTraveller': senderRole != 'traveller',
      'unreadForPartner': senderRole != 'partner',
    });
  }

  /// Clears the unread flag for whichever side just opened the thread.
  Future<void> markRead({required String chatId, required String asRole}) {
    return _chats.doc(chatId).update({
      if (asRole == 'traveller') 'unreadForTraveller': false else 'unreadForPartner': false,
    });
  }

  InsuranceChatSummary _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return InsuranceChatSummary(
      id: d.id,
      travellerId: (data['travellerId'] as String?) ?? '',
      travellerName: (data['travellerName'] as String?) ?? '',
      partnerId: (data['partnerId'] as String?) ?? '',
      providerName: (data['providerName'] as String?) ?? '',
      planName: data['planName'] as String?,
      lastMessage: (data['lastMessage'] as String?) ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastSenderRole: (data['lastSenderRole'] as String?) ?? '',
      unreadForTraveller: (data['unreadForTraveller'] as bool?) ?? false,
      unreadForPartner: (data['unreadForPartner'] as bool?) ?? false,
    );
  }

  /// Every thread a traveller has started, most recently active first.
  // Sorts client-side after the query, rather than chaining .orderBy()
  // onto the .where() in Firestore itself, which would need a composite
  // index for (travellerId ==, lastMessageAt desc) that this project has
  // never created (firestore.indexes.json has none) — that combination
  // was silently failing forever (StreamBuilder never got hasError
  // checked either, compounding it into an infinite "loading" spinner
  // on InsuranceMessagesPage). Mirrors admin_web/js/data.js's
  // listInsuranceChats, which already does the same where-only-then-
  // sort-in-JS to avoid needing that index on the partner console side.
  Stream<List<InsuranceChatSummary>> watchChatsForTraveller(String travellerId) {
    return _chats.where('travellerId', isEqualTo: travellerId).snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => (b.lastMessageAt ?? DateTime(0)).compareTo(a.lastMessageAt ?? DateTime(0)));
      return list;
    });
  }

  /// Every thread a partner has with any traveller, most recently active
  /// first — used by the partner console's inbox. See
  /// [watchChatsForTraveller]'s doc comment for why this sorts
  /// client-side instead of chaining .orderBy() in the query.
  Stream<List<InsuranceChatSummary>> watchChatsForPartner(String partnerId) {
    return _chats.where('partnerId', isEqualTo: partnerId).snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => (b.lastMessageAt ?? DateTime(0)).compareTo(a.lastMessageAt ?? DateTime(0)));
      return list;
    });
  }
}
