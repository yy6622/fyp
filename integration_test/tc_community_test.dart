// Community Module - TC37, TC38, TC39, TC72 (FR62/FR64 edit/delete own post),
// TC74 (FR70 report a post).
//
// TC38/TC39 call the real content-moderation service, which asks the Gemini
// API (key in lib/config/secrets.dart). They need internet on the device; if
// the key is missing or over quota the service lets text through and these two
// tests fail - that is a real result, not a test bug.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voya/repositories/community_repository.dart';

import 'helpers/test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestUser author, reader;
  final repo = CommunityRepository.instance;

  Future<String> postIdTitled(String title) async =>
      (await ownerList('posts')).firstWhere((p) => p['title'] == title)['id'] as String;

  setUpAll(() async {
    await initTestEnv();
    await resetEmulators();
    reader = await createTraveller('Reader Ray');
    author = await createTraveller('Author Ann');
  });

  testWidgets('TC37 Create a post with hashtags that other travellers can see', (tester) async {
    await signInAs(author);
    final flagged = await repo.createPost(
      authorId: author.uid,
      author: author.name,
      title: 'Bangkok food trip',
      description: 'Three days of street food around Yaowarat and Chatuchak.',
      location: 'Bangkok, Thailand',
      tags: const ['#Bangkok', '#Food'],
    );
    expect(flagged, isFalse, reason: 'clean text is not flagged');

    await signInAs(reader);
    final feed = await repo.watchPosts(reader.uid).first;
    final post = feed.firstWhere((p) => p.title == 'Bangkok food trip');
    expect(post.tags, ['bangkok', 'food']);
    expect(feed.where((p) => p.tags.contains('bangkok')), isNotEmpty, reason: 'hashtag search finds it');
  });

  testWidgets('TC38 A post with profanity is held back from other travellers', (tester) async {
    await signInAs(author);
    final flagged = await repo.createPost(
      authorId: author.uid,
      author: author.name,
      title: 'Worst trip ever',
      description: 'This hotel is shit and the staff are fucking idiots.',
      location: 'Bangkok, Thailand',
    );
    expect(flagged, isTrue, reason: 'moderation must flag the profanity');

    final stored = await ownerGet('posts/${await postIdTitled('Worst trip ever')}');
    expect(stored?['autoFlagged'], isTrue);
    expect(stored?['reported'], isTrue, reason: 'it lands in the admin Content Moderation queue');

    await signInAs(reader);
    final feed = await repo.watchPosts(reader.uid).first;
    expect(feed.map((p) => p.title), isNot(contains('Worst trip ever')));
  });

  testWidgets('TC39 A review with profanity is held back', (tester) async {
    final postId = await postIdTitled('Bangkok food trip');
    await signInAs(reader);
    final flagged = await repo.addReview(postId,
        authorId: reader.uid, authorName: reader.name, rating: 1, comment: 'What a load of crap, you moron.');
    expect(flagged, isTrue);

    await signInAs(author);
    final reviews = await repo.watchReviews(postId, myUid: author.uid).first;
    expect(reviews.where((r) => r.comment.contains('moron')), isEmpty, reason: 'other people do not see it');
  });

  testWidgets('TC39b A clean review with a rating is shown', (tester) async {
    final postId = await postIdTitled('Bangkok food trip');
    await signInAs(reader);
    expect(
        await repo.addReview(postId, authorId: reader.uid, authorName: reader.name, rating: 5, comment: 'Great tips, thanks!'),
        isFalse);
    await signInAs(author);
    final reviews = await repo.watchReviews(postId, myUid: author.uid).first;
    expect(reviews.map((r) => r.rating), contains(5));
  });

  testWidgets('TC74 Reporting a post sends it to the admin queue (FR70)', (tester) async {
    final postId = await postIdTitled('Bangkok food trip');
    await signInAs(reader);
    await repo.reportPost(postId, reportedByUid: reader.uid, reason: 'Spam');
    final stored = await ownerGet('posts/$postId');
    expect(stored?['reported'], isTrue);
    expect(stored?['reportedBy'], reader.uid);
    expect(stored?['reportReason'], 'Spam');
  });

  testWidgets('TC72 Only the author can edit or delete their post (FR62, FR64)', (tester) async {
    final postId = await postIdTitled('Bangkok food trip');

    await signInAs(reader);
    await expectDenied(() => repo.deletePost(postId), reason: 'someone else deletes the post');
    await expectDenied(() => repo.updatePost(postId, title: 'hijacked', description: ''),
        reason: 'someone else edits the post');

    await signInAs(author);
    await repo.updatePost(postId, title: 'Bangkok street food guide', description: 'Updated', tags: const ['food']);
    expect((await ownerGet('posts/$postId'))?['title'], 'Bangkok street food guide');
    await repo.deletePost(postId);
    expect(await ownerGet('posts/$postId'), isNull);
    expect(FirebaseAuth.instance.currentUser?.uid, author.uid);
  });
}
