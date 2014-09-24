### Warning: This framework is still growing and a work in progress. There are some serious issues that need to be fixed before I recommend using it in production. Also, most of the code is still untested.

Spine
=====
Spine is an Swift framework that works with a JSON API that adheres to the jsonapi.org spec. Although it comes out of the box configured for jsonapi.org, the goal is to make it flexible enough to work with other JSON APIs as well.

Quickstart
==========
The easiest way to use Spine is via a singleton. Spine exposes a singleton via `Spine.sharedInstance`.

### 1. Configure the API baseURL
```swift
Spine.sharedInstance.baseURL = "http://api.example.com/v1"
```

### 2. Register your resource classes
Every resource should have a class, subclassed from `Resource`. This class should override the public variables `resourceType` and `persistentAttributes`. The `resourceType` should contain the type of resource in plural form. The `persistentAttributes` should contain an array of attributes that must be persisted by Spine. Attributes that are not in this array are ignored by Spine.

```swift
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

## 3. Fetching resources
```swift
// Using simple find methods
Post.findOne("1") // Fetch a single post with ID 1
Post.find(["1", "2", "3"]) // Fetch multiple posts with IDs 1, 2, and 3
Post.findAll() // Fetch all posts

// Using a complex query
let query = Query(resourceType: "posts")
    .include(["author", "comments", "comments.author"]) // Sideload relationships
    .whereProperty("upvotes", greaterThanOrEqualTo: 8) // Only with 8 or more upvotes
    .whereRelationship("author", isOrContains: user) // Where the author is a given user
    
query.findResources() // Execute the query

// Fetch related resources
let query = Query(resource: post, relationship: "author")
query.findResources()
```

## 4. Saving resources
A resource can be saved by calling the `saveInBackground` function on a resource instance. Extra care MUST be taken regarding related resources. Saving does not automatically save any related resources. You must explicitly save these yourself beforehand. If you added a new create resource to a parent resource, you must first save the child resource (to obtain an ID), before saving the parent resource.

## 5. Deleting resources
A resource can be deleted by calling the `deleteInBackground` function on a resource instance. Deleting does not cascade on the client.

## 6. Read the wiki
The wiki contains much more information about using Spine. Godspeed, and remember, respect is everything.
