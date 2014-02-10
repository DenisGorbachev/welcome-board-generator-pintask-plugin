share.insertCode = ->
  code = share.getCode()
  $codeContainer = $(".code-container")
  if !$codeContainer.length
    $codeContainer = $("<textarea class='code-container'></textarea>")
    $boardEditForm = $(".board-edit form")
    $boardEditForm.prepend($codeContainer)
  $codeContainer.text(code)
  $codeContainer.select()

share.insertLink = ->
  currentRoute = Router.current({reactive: false})
  if !currentRoute
    return
  routeName = currentRoute.route.name
  if routeName is "boardEdit"
    $getCodeLink = $("<li><a href='#' class='get-code-link'>Получить код доски</a></li>").on("click", share.insertCodeListener)
    $boardActions = $(".board-actions")
    if $boardActions.length
      $boardActions.prepend($getCodeLink)
      share.insertCode()

share.insertCodeListener = encapsulate (event) ->
  event.preventDefault()
  share.insertCode()

# pass into file scope
code = ""
embeddedLists = []
oldCardIds2newCardIds = {}

share.getCode = ->
  # re-initialize
  code = ""
  embeddedLists = []
  code = '
share.createFeaturesBoard = ->\n
  mirroredCardId = Random.id()\n
  Boards.insert(\n'
  boardId = Router.current({reactive: false}).params.boardId
  board = Boards.findOne(boardId, {reactive: false})
  code += '
    name: "' + board.name + '"\n
    color: "' + board.color + '"\n
  , (error, boardId) ->\n'
  Lists.find({boardId: boardId, cardId: {$exists: true}}, {sort: {position: 1}, reactive: false}).forEach (list) ->
    embeddedLists.push(list)
  Lists.find({boardId: boardId, cardId: {$exists: false}}, {sort: {position: 1}, reactive: false}).forEach(_.partial(share.processList, 4))
  code += '
  )
'
  code

share.processList = (padding, list) ->
  listId = list._id
  delete list._id
  delete list.ownerId
  delete list.memberIds
  delete list.updatedAt
  delete list.createdAt
  code += _.string.repeat(" ", padding) + 'Lists.insert('
  listCode = JSON.stringify(list, null, padding + 2)
  listCode = listCode.replace(/"boardId": "[^"]+"/, '"boardId": boardId')
  listCode = listCode.replace(/"cardId": "[^"]+"/, '"cardId": cardId')
  listCode = listCode.replace(/}$/, _.string.repeat(" ", padding) + "}")
  code += listCode
  code += ', (error, listId) ->\n'
  Cards.find({listId: listId}, {sort: {position: 1}, reactive: false, transform: false}).forEach (card) ->
    cardId = card._id
    delete card._id
    delete card.searchIndex
    delete card.ownerId
    delete card.updatedAt
    delete card.createdAt
    totalMirrorsCount = card.totalMirrorsCount
    delete card.totalMirrorsCount
    if card.memberIds.length
      hasMemberIds = true
      card.memberIds = null
    for comment in card.comments
      delete comment.ownerId
      delete comment.updatedAt
      delete comment.createdAt
    code += _.string.repeat(" ", padding + 2) + 'Cards.insert('
    cardCode = JSON.stringify(card, null, padding + 4)
    cardCode = cardCode.replace(/"listId": .+/, '"listId": listId')
    cardCode = cardCode.replace(/}$/, _.string.repeat(" ", padding + 2) + "}")
    if card.deadlineAt
      cardCode = cardCode.replace(/"deadlineAt": "([^"]+)"/, '"deadlineAt": new Date("$1")')
    if hasMemberIds
      cardCode = cardCode.replace(/"memberIds": .+/, '"memberIds": [Meteor.userId()]')
    if totalMirrorsCount
      if card.originalId && card.originalId != cardId
        cardCode = cardCode.replace(/"originalId": .+/, '"originalId": mirroredCardId')
      else
        cardCode = cardCode.replace(/\{/, '\{\n' + _.string.repeat(" ", padding + 4) + '_id: mirroredCardId,')
    code += cardCode
    code += ', (error, cardId) ->\n'
    processedEmbeddedLists = []
    for embeddedList in embeddedLists
      if embeddedList.cardId == cardId
        share.processList(padding + 4, embeddedList)
        processedEmbeddedLists.push(embeddedList)
    embeddedLists = _.without(embeddedLists, processedEmbeddedLists...)
    code += _.string.repeat(" ", padding + 2) + ')\n'
  code += _.string.repeat(" ", padding) + ')\n'

Template.boardEdit.rendered = _.compose(share.insertLink, Template.boardEdit.rendered)
share.insertLink()

share = share || {}
