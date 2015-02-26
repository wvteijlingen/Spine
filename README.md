Spine
=====
Spine is an Swift framework for consuming a JSON API that adheres to the jsonapi.org spec.

Quickstart
==========
### 1. Instantiate a Spine
```swift
let baseURL = NSURL(string: "http://api.example.com/v1")
let spine = Spine(baseURL: baseURL)
```

### 2. Register your resource classes
Every resource is mapped to a class that implements the `ResourceProtocol` protocol. Spine comes with a `Resource` class that implements this protocol.
A `Resource` subclass should override the variables `resourceType` and `attributes`. The `resourceType` should contain the type of resource in plural form. The `attributes` array should contain an array of attributes that must be persisted. Attributes that are not in this array are ignored.

Each class must be registered using a factory method. This is done using the `registerResource` method.

```swift
// Resource class
class Post: Resource {
	dynamic var title: String?
	dynamic var body: String?
	dynamic var author: User?
	dynamic var comments: LinkedResourceCollection?

	override class var resourceType: String {
		return "posts"
	}

	override var attributes: [Attribute] {
		return attributesFromDictionary([
			"title": PropertyAttribute(),
			"body": PropertyAttribute().serializeAs("content"),
			"author": ToOneAttribute(User.resourceType),
			"comments": ToManyAttribute(Comment.resourceType)
		])
	}
}


// Register resource class
spine.registerResource(Post.resourceType) { Post() }
```

### 3. Fetching resources
```swift
// Using simple find methods
spine.find(["1", "2"], ofType: Post.self) // Fetch posts with ID 1 and 2
spine.findOne("1", ofType: Post.self)  // Fetch a single posts with ID 1
spine.find(Post.self) // Fetch all posts
spine.findOne(Post.self) // Fetch the first posts

// Using a complex query
var query = Query(resourceType: Post.self)
query.include("author", "comments", "comments.author") // Sideload relationships
query.whereProperty("upvotes", equalTo: 8) // Only with 8 upvotes
query.addAscendingOrder("creationDate") // Sort on creation date
spine.find(query)
```

All fetch methods return a Future with `onSuccess` and `onFailure` callbacks.

### 4. Saving resources
```swift
spine.save(post).onSuccess {
    println("Saving success")
.onFailure { error in
    println("Saving failed: \(error)")
}
```
Extra care MUST be taken regarding related resources. Saving does not automatically save any related resources. You must explicitly save these yourself beforehand. If you added a new create resource to a parent resource, you must first save the child resource (to obtain an ID), before saving the parent resource.

### 5. Deleting resources
```swift
spine.delete(post).onSuccess {
    println("Deleting success")
.onFailure { error in
    println("Deleting failed: \(error)")
}
```
Deleting does not cascade on the client.

### 6. Read the wiki
The wiki contains much more information about using Spine.