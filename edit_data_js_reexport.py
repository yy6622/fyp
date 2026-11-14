import io
path = "admin_web/js/data.js"
with io.open(path, encoding="utf-8") as f:
    s = f.read()
old = '''import {
  collection, collectionGroup, doc, getDoc, getDocs, addDoc, updateDoc, deleteDoc,
  setDoc, query, where, limit, serverTimestamp, deleteField, increment, arrayUnion,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore.js";'''
new = old + '''
// Re-exported so pages that need to stamp a timestamp or clear a field as
// part of a bigger write they build themselves (e.g.
// partner/plan-form.html's submit-for-review flow) don't need their own
// separate Firestore SDK import just for these two.
export { serverTimestamp, deleteField };'''
assert s.count(old) == 1
s = s.replace(old, new, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("ok")
