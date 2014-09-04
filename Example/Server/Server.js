var fortune = require('fortune')
  , app = fortune({
    db: 'spine_example'
  })
  .resource('post', {
    title: String,
    body: String,
    creationDate: Date,
    author: 'user',
    comments: ['comment']
  })
  .resource('user', {
    username: String,
    posts: ['post'],
    comments: ['comment']
  })
  .resource('comment', {
    body: String,
    author: 'user',
    post: 'post'
  })
  .listen(1337);