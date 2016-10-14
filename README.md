[![Build Status](https://travis-ci.org/wvteijlingen/Spine.svg?branch=swift-2.0)](https://travis-ci.org/wvteijlingen/Spine) [![Join the chat at https://gitter.im/wvteijlingen/Spine](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/wvteijlingen/Spine?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

# Spine
Spine is a Swift library for working with APIs that adhere to the [jsonapi.org](http://jsonapi.org) standard. It supports mapping to custom model classes, fetching, advanced querying, linking and persisting.

## Stability
This library was born out of a hobby project. Some things are still lacking, one of which is test coverage. Beware of this when using Spine in a production app!

## Table of Contents
- [Supported features](#supported-features)
- [Installation](#installation)
- [Configuration](#configuration)
	- [Defining resource types](#defining-resource-types)
	- [Defining resource fields](#defining-resource-fields)
	- [Example resource class](#example-resource-class)
- [Usage](#usage)
	- [Fetching resources](#fetching-resources)
	- [Saving resources](#saving-resources)
	- [Deleting resources](#deleting-resources)
	- [Loading and reloading resources](#loading-and-reloading-resources)
	- [Pagination](#pagination)
	- [Filtering](#filtering)
	- [Networking](#networking)
	- [Logging](#logging)
	- [Memory management](#memory-management)
	- [Using the serializer separately](#using-the-serializer-separately)

## Supported features
| Feature                        | Supported | Note                                            |
| ------------------------------ | --------- | ----------------------------------------------- |
| Fetching resources             | Yes       |                                                 |
| Creating resources             | Yes       |                                                 |
| Updating resources             | Yes       |                                                 |
| Deleting resources             | Yes       |                                                 |
| Top level metadata             | Yes       |                                                 |
| Top level errors               | Yes       |                                                 |
| Top level links                | Yes       |                                                 |
| Top level JSON API Object      | Yes       |                                                 |
| Client generated ID's          | Yes       |                                                 |
| Resource metadata              | Yes       |                                                 |
| Custom resource links          | No        |                                                 |
| Relationships                  | Yes       |                                                 |
| Inclusion of related resources | Yes       |                                                 |
| Sparse fieldsets               | Partially | Fetching only, all fields will be saved         |
| Sorting                        | Yes       |                                                 |
| Filtering                      | Yes       | Supports custom filter strategies               |
| Pagination                     | Yes       | Offset, cursor and custom pagination strategies |
| Bulk extension                 | No        |                                                 |
| JSON Patch extension           | No        |                                                 |

## Installation
### Carthage
Add `github "wvteijlingen/Spine" "master"` to your Cartfile. See the [Carthage documentation](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application) for instructions on how to integrate with your project using Xcode.

### Cocoapods
Add `pod 'Spine', :git => 'https://github.com/wvteijlingen/Spine.git'` to your Podfile. The spec is not yet registered with the Cocoapods repository, because the library is still in flux.

## Configuration
### Defining resource types
Every resource is mapped to a class that inherits from `Resource`. A subclass should override the variables `resourceType` and `fields`. The `resourceType` should contain the type of resource in plural form. The `fields` array should contain an array of fields that must be persisted. Fields that are not in this array are ignored.

Each class must be registered using the `Spine.registerResource` method.

### Defining resource fields
You need to specify the fields that must be persisted using an array of `Field`s. These fields are used when turning JSON into resources instances and vice versa. The name of each field corresponds to a variable on your resource class. This variable must be specified as optional.

#### Field name formatters
By default, the key in the JSON will be the same as your field name or serialized field name. You can specify a different name by using serializeAs(name: String). The name or custom serialized name will be mapped to a JSON key using a `KeyFormatter`. You can configure the key formatter using the `keyFormatter` variable on a Spine instance.

Spine comes with three key formatters: `AsIsKeyFormatter`, `DasherizedKeyFormatter`, `UnderscoredKeyFormatter`.

```swift
// Formats a field name 'myField' to key 'MYFIELD'.
public struct AllCapsKeyFormatter: KeyFormatter {
	public func format(field: Field) -> String {
		return field.serializedName.uppercaseString
	}
}

spine.keyFormatter = AllCapsKeyFormatter()
```

#### Built in attribute types

##### Attribute
An attribute is a regular attribute that can be serialized by NSJSONSerialization. E.g. a String or NSNumber.

##### URLAttribute
An url attribute corresponds to an NSURL variable. These are represented by strings in the JSON document. You can instantiate it with a baseURL, in which case Spine will expand relative URLs from the JSON relative to the given baseURL. Absolute URLs will be left as is.

##### DateAttribute
A date attribute corresponds to an NSDate variable. By default, these are represented by ISO 8601 strings in the JSON document. You can instantiate it with a custom format, in which case that format will be used when serializing and deserializing that particular attribute.

##### ToOneRelationship
A to-one relationship corresponds to another resource. You must instantiate it with the type of the linked resource.

##### ToManyRelationship
A to-many relationship corresponds to a collection of other resources. You must instantiate it with the type of the linked resources. If the linked types are not homogenous, they must share a common ancestor as the linked type. To many relationships are mapped to LinkedResourceCollection objects.

#### Custom attribute types
Custom attribute types can be created by subclassing `Attribute`. A custom attribute type must have a registered transformer that handles serialization and deserialization.

Transformers are registered using the `registerTransformer` method. A transformer is a class or struct that implements the `Transformer` protocol.

```swift
public class RomanNumeralAttribute: Attribute { }

struct RomanNumeralValueFormatter: ValueFormatter {
	func unformat(value: String, attribute: RomanNumeralAttribute) -> AnyObject {
		let integerRepresentation: NSNumber = // Magic...
		return integerRepresentation
	}

	func format(value: NSNumber, attribute: RomanNumeralAttribute) -> AnyObject {
		let romanRepresentation: String = // Magic...
		return romanRepresentation
	}
}
spine.registerValueFormatter(RomanNumeralValueFormatter())
```

### Example resource class

```swift
// Resource class
class Post: Resource {
	var title: String?
	var body: String?
	var creationDate: NSDate?
	var author: User?
	var comments: LinkedResourceCollection?

	override class var resourceType: ResourceType {
		return "posts"
	}

	override class var fields: [Field] {
		return fieldsFromDictionary([
			"title": Attribute(),
			"body": Attribute().serializeAs("content"),
			"creationDate": DateAttribute(),
			"author": ToOneRelationship(User),
			"comments": ToManyRelationship(Comment)
		])
	}
}

spine.registerResource(Post)
```

## Usage
### Fetching resources
Resources can be fetched using find methods:
```swift
// Fetch posts with ID 1 and 2
spine.find(["1", "2"], ofType: Post).onSuccess { resources, meta, jsonapi in
  println("Fetched resource collection: \(resources)")
.onFailure { error in
  println("Fetching failed: \(error)")
}

spine.findAll(Post) // Fetch all posts
spine.findOne("1", ofType: Post)  // Fetch a single posts with ID 1
```

Alternatively, you can use a Query to perform a more advanced find:
```swift
var query = Query(resourceType: Post)
query.include("author", "comments", "comments.author") // Sideload relationships
query.whereProperty("upvotes", equalTo: 8) // Only with 8 upvotes
query.addAscendingOrder("creationDate") // Sort on creation date

spine.find(query).onSuccess { resources, meta, jsonapi in
  println("Fetched resource collection: \(resources)")
.onFailure { error in
  println("Fetching failed: \(error)")
}
```

All fetch methods return a Future with `onSuccess` and `onFailure` callbacks.

### Saving resources
```swift
spine.save(post).onSuccess { _ in
    println("Saving success")
.onFailure { error in
    println("Saving failed: \(error)")
}
```
Extra care MUST be taken regarding related resources. Saving does not automatically save any related resources. You must explicitly save these yourself beforehand. If you added a new create resource to a parent resource, you must first save the child resource (to obtain an ID), before saving the parent resource.

### Deleting resources
```swift
spine.delete(post).onSuccess {
    println("Deleting success")
.onFailure { error in
    println("Deleting failed: \(error)")
}
```
Deleting does not cascade on the client.

### Loading and reloading resources
You can use the `Spine.load` methods to make sure resources are loaded. If it is already loaded, it returns the resource as is. Otherwise it loads the resource using the passed query.

The `Spine.reload` method works similarly, except that it always reloads a resource. This can be used to make sure a resource contains the latest data from the server.

### Pagination
You can fetch next and previous pages of collections by using: `Spine.loadNextPageOfCollection` and `Spine.loadPreviousPageOfCollection`.

JSON:API is agnostic about pagination strategies. Because of this, Spine by default only supports two pagination strategies:
- Page based pagination using the `page[number]` and `page[size]` parameters
- Offset based pagination using the `page[offset]` and `page[limit]` parameters

You can add a custom filter strategy by creating a new type that conforms to the `Pagination` protocol, and then subclassing the built in `Router` class and overriding the `queryItemsForPagination(pagination: Pagination)` method.

#### Example: implementing 'cursor' based pagination
In this example, cursor based pagination is added a using the `page[limit]`, and either a `page[before]` or `page[after]` parameter.

```swift
public struct CursorBasedPagination: Pagination {
	var beforeCursor: String?
	var afterCursor: String?
	var limit: Int
}
```

```swift
class CustomRouter: Router {
	override func queryItemsForPagination(pagination: Pagination) -> [NSURLQueryItem] {
		if let cursorPagination = pagination as? CursorBasedPagination {
			var queryItems = [NSURLQueryItem(name: "page[limit]", value: String(cursorPagination.limit))]

			if let before = cursorPagination.beforeCursor {
				queryItems.append(NSURLQueryItem(name: "page[before]", value: before))
			} else if let after = cursorPagination.afterCursor {
				queryItems.append(NSURLQueryItem(name: "page[after]", value: after))
			}

			return queryItems
		} else {
			return super.queryItemsForPagination(pagination)
		}
	}
}
```

### Filtering
JSON:API is agnostic about filter strategies. Because of this, Spine by default only supports 'is equal to' filtering in the form of `?filter[key]=value`.

You can add a custom filter strategy by subclassing the built in `Router` class and overriding the `queryItemForFilter(filter: NSComparisonPredicate)` method. This method takes a comparison predicate and returns a matching `NSURLQueryItem`.

#### Example: implementing a 'not equal to' filter
In this example, a switch statement is used to add a 'not equal filer in the form of `?filter[key]=!value`.

```swift
class CustomRouter: Router {
	override func queryItemForFilter(field: Field, value: AnyObject, operatorType: NSPredicateOperatorType) -> NSURLQueryItem {
		switch operatorType {
		case .NotEqualToPredicateOperatorType:
			let key = keyFormatter.format(field)
			return NSURLQueryItem(name: "filter[\(key)]", value: "!\(value)")
		default:
			return super.queryItemForFilter(filter)
		}
	}
}

let baseURL = NSURL(string: "http://api.example.com/v1")
let spine = Spine(baseURL: baseURL, router: CustomRouter())
```

### Networking
Spine uses a `NetworkClient` to communicate with the remote API. By default it uses the `HTTPClient` class which performs request over the HTTP protocol.

#### Customising HTTP headers of HTTPClient
The `HTTPClient` class supports setting HTTP headers as follows:
```swift
(spine.networkClient as! HTTPClient).setHeader("User-Agent", to: "My App")
(spine.networkClient as! HTTPClient).removeHeader("User-Agent")
```

#### Using a custom network client
You can use a custom client by subclassing `HTTPClient` or by creating a class that implements the `NetworkClient` protocol. Pass an instance of this class when instantiating a Spine:

```swift
var customClient = CustomNetworkClient()
var spine = Spine(baseURL: NSURL(string:"http://example.com")!, networkClient: customClient)
```

### Logging
Spine comes with a rudimentary logging system. Each logging domain can be configured with a certain log level:

```swift
Spine.setLogLevel(.Debug, forDomain: .Spine)
Spine.setLogLevel(.Info, forDomain: .Networking)
Spine.setLogLevel(.Warning, forDomain: .Serializing)
```

These levels are global, meaning they apply to all Spine instances.

#### Log domains
* Spine: The main Spine component.
* Networking: The networking component, requests, responses etc.
* Serializing: The (de)serializing component.

#### Log levels
* Debug
* Info
* Warning
* Error
* None

#### Custom loggers
The default `ConsoleLogger` logs to the console using the Swift built in `print` command. You can assign a custom logger that implements the `Logger` protocol to the
static `Spine.logger` variable.

### Memory management
Spine suffers from the same memory management issues as Core Data, namely retain cycles for recursive relationships. These cycles can be broken in two ways:

1. Declare one end of the relationship as `weak` or `unowned`.
2. Use a Resource's `unload` method to break cycles when you are done with the resource.

## Using the serializer separately
You can also just use the Serializer to (de)serialize to and from JSON:

```swift
let serializer = Serializer()

// Register resources
serializer.registerResource(Post)

// Optional configuration
serializer.registerValueFormatter(RomanNumeralValueFormatter())
serializer.keyFormatter = DasherizedKeyFormatter()

// Convert NSData to a JSONAPIDocument struct
let data = fetchData()
let document = try! serializer.deserializeData(data)

// Convert resources to NSData
let data = try! serializer.serializeResources([post])

// Convert resources to link data
let data = try! serializer.serializeLinkData(post)
let data = try! serializer.serializeLinkData([firstPost, secondPost])
```
