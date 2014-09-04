Documentation
=========

## Implementing Spine
The easiest way to use Spine is via a singleton. Spine exposes a singleton via `Spine.sharedInstance`. If you want to use multiple Spines in your application, or if you don't want to use singletons, you can do this by creating separate instances using `Spine(endPoint: String)`. However, you cannot use the convenience functions without a singleton.

## Configuring Spine

### API endpoint
```
Spine.sharedInstance.endPoint = "http://api.example.com/v1"
```

### Resource classes
Every resource should have a class, subclassed from `Resource`. This class should override the public variables `resourceType` and `persistentAttributes`. The `resourceType` should contain the type of resource in plural form. The `persistentAttributes` should contain an array of attributes that must be persisted by Spine. Attributes that are not in this array are ignored by Spine.
```
class Post: Resource {
	var title: String?
	var body: String?
	var author: User?
	override var resourceType: String {
		return "posts"
	}
	override var persistentAttributes: [String: ResourceAttribute] {
		return ["title": ResourceAttribute.Property,
		        "body": ResourceAttribute.Property,
		        "author": ResourceAttribute.ToOne]
	}
}
```

### Registering resources
Each resource class should be registered using the `registerType` function. For example, registering the Post class: `spine.registerType(Post.self)`.

## Promises
All convienience operations return futures using the `BrightFutures` futures library. This makes it easy to chain requests and respond to success or failure. See the `BrightFutures` documentation and the examples below on how to use futures.

## Fetching resources
*The following functions are convenience functions that proxy to the global Spine singleton. Therefore, you can only use them if you use Spine as a singleton.*

### Fetching using find functions
You can fetch resources by using the `find`, `findOne` and `findAll`class function of the resource class you want to fetch.
```
Post.findOne("1") // Fetch a single post with ID 1
Post.find(["1", "2", "3"]) // Fetch multiple posts with IDs 1, 2, and 3
Post.findAll() // Fetch all posts
```

### Fetching using a query
More complicated fetches can be done using the Query class. A query can be configured with 'where' filters, sideloading, and sparse fieldsets.
```
let query = Query(resourceType: "posts")
    .include(["author", "comments", "comments.author"]) // Sideload relationships
    .whereProperty("upvotes", greaterThanOrEqualTo: 8) // Only with 8 or more upvotes
    .whereRelationship("author", isOrContains: user) // Where the author is a given user
    
query.findResources() // Execute the query
```

### Fetching related resources
Related resources can be fetched using a query.
```
// Assuming 'post' is a fetched resource, fetch its author
let query = Query(resource: post, relationship: "author")
query.findResources()
```

## Saving resources
A resource can be saved by calling the `saveInBackground` function on a resource instance. Extra care MUST be taken regarding related resources. Saving does not automatically save any related resources. You must explicitly save these yourself beforehand. If you added a new create resource to a parent resource, you must first save the child resource (to obtain an ID), before saving the parent resource.

## Deleting resources
A resource can be deleted by calling the `deleteInBackground` function on a resource instance. Deleting does not cascade on the client.

## Operating without a singleton
All of the above operations are convenience operations that work on a Spine singleton instance. If you do not wish to use a singleton, the following functions are available on each Spine instance:

```
let spine = Spine(endPoint: "http://api.example.com/v1")

// Fetch a single post with ID 1 
spine.fetchResourceWithType("posts", ID: "1").onSuccess { resource in
    println(resource)
}.onFailure: { error in
    println(error)
}

 // Fetch the author of a post
spine.fetchResourcesForRelationship("author", ofResource: post).onSuccess { resources in
    println(resources)
}.onFailure: { error in
    println(error)
}

// Execute a query
spine.fetchResourcesForQuery(query).onSuccess { resources in
    println(resources)
}.onFailure: { error in
    println(error)
}

 // Save a resource
spine.saveResource(resource).onSuccess { resource in
    println("Saving successful")
}.onFailure: { error in
    println("Error saving")
}

// Delete a resource
spine.deleteResource(resource).onSuccess { 
    println("Deleting successful")
}.onFailure: { error in
    println("Error deleting")
}