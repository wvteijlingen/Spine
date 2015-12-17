[![Build Status](https://travis-ci.org/wvteijlingen/Spine.svg?branch=swift-2.0)](https://travis-ci.org/wvteijlingen/Spine) [![Join the chat at https://gitter.im/wvteijlingen/Spine](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/wvteijlingen/Spine?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Spine
=====
Spine is a Swift library for working with APIs that adhere to the [jsonapi.org](http://jsonapi.org) standard. It supports mapping to custom model classes, fetching, advanced querying, linking and persisting.

Stability
============
This library was born out of a hobby project. Some things are still lacking, one of which is test coverage. Beware of this when using Spine in a production app!

Supported features
==================
| Feature                        | Enabled   | Note                                                        |
| ------------------------------ | --------- | ----------------------------------------------------------- |
| Fetching resources             | Yes       |                                                             |
| Creating resources             | Yes       |                                                             |
| Updating resources             | Yes       |                                                             |
| Deleting resources             | Yes       |                                                             |
| Top level metadata             | Yes        |                                                             |
| Top level errors               | Yes       |                                                             |
| Top level links                | Partially | Currently only pagination links are supported               |
| Top level JSON API Object      | Yes        |                                                             |
| Client generated ID's          | No        |                                                             |
| Resource metadata              | Yes       |                                                             |
| Custom resource links          | No        |                                                             |
| Relationships                  | Yes       |                                                             |
| Inclusion of related resources | Yes       |                                                             |
| Sparse fieldsets               | Partially | Fetching only, all fields will be saved                     |
| Sorting                        | Yes       |                                                             |
| Filtering                      | Yes       | Supports custom filter strategies                           |
| Pagination                     | Yes       | Offset based, cursor based and custom pagination strategies |
| Bulk extension                 | No        |                                                             |
| JSON Patch extension           | No        |                                                             |

Installation
============

### Carthage
Add `github "wvteijlingen/Spine"` to your Cartfile. See the [Carthage documentation](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application) for instructions on how to integrate with your project using Xcode.

### Cocoapods
Add `pod 'Spine', :git => 'https://github.com/wvteijlingen/Spine.git'` to your Podfile. The spec is not yet registered with the Cocoapods repository, because the library is still in flux.

Quickstart
==========
### 1. Instantiate a Spine
```swift
let baseURL = NSURL(string: "http://api.example.com/v1")
let spine = Spine(baseURL: baseURL)
```

### 2. Register your resource classes
Every resource is mapped to a class that inherits from `Resource`. A subclass should override the variables `resourceType` and `fields`. The `resourceType` should contain the type of resource in plural form. The `fields` array should contain an array of fields that must be persisted. Fields that are not in this array are ignored.

Each class must be registered using a factory method. This is done using the `registerResource` method.

```swift
// Resource class
class Post: Resource {
	dynamic var title: String?
	dynamic var body: String?
	dynamic var creationDate: NSDate?
	dynamic var author: User?
	dynamic var comments: LinkedResourceCollection?

	override class var resourceType: String {
		return "posts"
	}

	override class var fields: [Field] {
		return fieldsFromDictionary([
			"title": Attribute(),
			"body": Attribute().serializeAs("content"),
			"creationDate": DateAttribute().serializeAs("created-at"),
			"author": ToOneRelationship(User.resourceType),
			"comments": ToManyRelationship(Comment.resourceType)
		])
	}
}


// Register resource class
spine.registerResource(Post.resourceType) { Post() }
```

### 3. Fetching resources

#### Using find methods
```swift
// Fetch posts with ID 1 and 2
spine.find(["1", "2"], ofType: Post.self).onSuccess { resources, meta, jsonapi in
    println("Fetched resource collection: \(resources)")
.onFailure { error in
    println("Fetching failed: \(error)")
}

spine.findAll(Post.self) // Fetch all posts
spine.findOne("1", ofType: Post.self)  // Fetch a single posts with ID 1
```

#### Using a Query
```swift
var query = Query(resourceType: Post.self)
query.include("author", "comments", "comments.author") // Sideload relationships
query.whereProperty("upvotes", equalTo: 8) // Only with 8 upvotes
query.addAscendingOrder("created-at") // Sort on creation date

spine.find(query).onSuccess { resources, meta, jsonapi in
    println("Fetched resource collection: \(resources)")
.onFailure { error in
    println("Fetching failed: \(error)")
}
```

All fetch methods return a Future with `onSuccess` and `onFailure` callbacks.

### 4. Saving resources
```swift
spine.save(post).onSuccess { _ in
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


Memory management
=================
Spine suffers from the same memory management issues as Core Data, namely retain cycles for recursive relationships. These cycles can be broken in two ways:

1. Declare one end of the relationship as `weak` or `unowned`.
2. Use a Resource's `unload` method to break cycles when you are done with the resource.
