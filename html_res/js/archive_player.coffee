window.console ||= {}
window.console.log ||= ->
window.console.error ||= ->

TSUPAIS = [null, "E", "S", "W", "N", "P", "F", "C"]

TSUPAI_IMAGE_MAP =
  "E": "ji_e"
  "S": "ji_s"
  "W": "ji_w"
  "N": "ji_n"
  "P": "no"
  "F": "ji_h"
  "C": "ji_c"

currentBoard =
  players: [{}, {}, {}, {}]
playerViews = [{}, {}, {}, {}]
loadedActions = []
currentActionId = 0

parsePai = (pai) ->
  if pai.match(/^([1-9])(.)(r)?$/)
    return {
      type: RegExp.$2
      number: parseInt(RegExp.$1)
      red: if RegExp.$3 then true else false
    }
  else
    return {
      type: "t"
      number: TSUPAIS.indexOf(pai)
      red: false
    }

comparePais = (lhs, rhs) ->
  parsedLhs = parsePai(lhs)
  lhsRep = parsedLhs.type + parsedLhs.number + (if parsedLhs.red then "1" else "0")
  parsedRhs = parsePai(rhs)
  rhsRep = parsedRhs.type + parsedRhs.number + (if parsedRhs.red then "1" else "0")
  if lhsRep < rhsRep
    return -1
  else if lhsRep > rhsRep
    return 1
  else
    return 0

sortPais = (pais) ->
  pais.sort(comparePais)

paiToImageUrl = (pai, pose) ->
  if pai
    parsedPai = parsePai(pai)
    if parsedPai.type == "t"
      name = TSUPAI_IMAGE_MAP[pai]
    else
      name = "#{parsedPai.type}s#{parsedPai.number}"
    if pose == undefined
      pose = 1
    return window.resourceDir + "/images/p_#{name}_#{pose}.gif"
  else
    return window.resourceDir + "/images/blank.png"

cloneBoard = (board) ->
  newBoard =
    players: []
  for player in board.players
    newPlayer = {}
    for key, value of player
      newPlayer[key] = value
    newBoard.players.push(newPlayer)
  return newBoard

initPlayers = (board) ->
  for player in board.players
    player.tehais = null
    player.furos = []
    player.ho = []
    player.reach = false
    player.reachHoIndex = null

loadAction = (action) ->
  
  console.log(action.type, action)
  currentBoard = cloneBoard(currentBoard)
  if "actor" of action
    actorPlayer = currentBoard.players[action.actor]
  else
    actorPlayer = null
  if "target" of action
    targetPlayer = currentBoard.players[action.target]
  else
    targetPlayer = null
  
  switch action.type
    when "start_game"
      initPlayers(currentBoard)
    when "end_game"
      null
    when "start_kyoku"
      initPlayers(currentBoard)
    when "end_kyoku"
      null
    when "haipai"
      actorPlayer.tehais = action.pais
      sortPais(actorPlayer.tehais)
    when "tsumo"
      actorPlayer.tehais = actorPlayer.tehais.concat([action.pai])
    when "dahai"
      deleteTehai(actorPlayer, action.pai)
      actorPlayer.ho = actorPlayer.ho.concat([action.pai])
    when "reach"
      actorPlayer.reachHoIndex = actorPlayer.ho.length
    when "reach_accepted"
      actorPlayer.reach = true
    when "chi", "pon"
      targetPlayer.ho = targetPlayer.ho[0...(targetPlayer.ho.length - 1)]
      for pai in action.consumed
        deleteTehai(actorPlayer, pai)
      actorPlayer.furos = actorPlayer.furos.concat([
          type: action.type
          taken: action.pai
          consumed: action.consumed
          target: action.target
      ])
    when "hora", "ryukyoku"
      null
    when "log"
      if loadedActions.length > 0
        loadedActions[loadedActions.length - 1].log = action.text
    else
      throw "unknown action: #{action.type}"
  
  for i in [0...4]
    if i != action.actor
      ripai(currentBoard.players[i])
  
  if action.type != "log"
    action.board = currentBoard
    #dumpBoard(currentBoard)
    loadedActions.push(action)

deleteTehai = (player, pai) ->
  player.tehais = player.tehais.concat([])
  idx = player.tehais.lastIndexOf(pai)
  throw "pai not in tehai" if idx < 0
  player.tehais[idx] = null

ripai = (player) ->
  if player.tehais
    player.tehais = (pai for pai in player.tehais when pai)
    sortPais(player.tehais)

dumpBoard = (board) ->
  for i in [0...4]
    player = board.players[i]
    if player.tehais
      tehaisStr = player.tehais.join(" ")
      for furo in player.furos
        consumedStr = furo.consumed.join(" ")
        tehaisStr += " [#{furo.taken}/#{consumedStr}]"
      console.log("[#{i}] tehais: #{tehaisStr}")
    if player.ho
      hoStr = player.ho.join(" ")
      console.log("[#{i}] ho: #{hoStr}")

renderPai = (pai, view, pose) ->
  if pose == undefined
    pose = 1
  view.attr("src", paiToImageUrl(pai, pose))
  switch pose
    when 1
      view.addClass("pai")
      view.removeClass("laid-pai")
    when 3
      view.addClass("laid-pai")
      view.removeClass("pai")
    else
      throw("unknown pose")

renderPais = (pais, view) ->
  view.clear()
  if pais
    for pai in pais
      renderPai(pai, view.append())

renderHo = (player, offset, pais, view) ->
  if player.reachHoIndex == null
    reachIndex = null
  else
    reachIndex = player.reachHoIndex - offset
  view.clear()
  for i in [0...pais.length]
    renderPai(pais[i], view.append(), if i == reachIndex then 3 else 1)

renderAction = (action) ->
  console.log(action.type, action)
  actorStr = if action.actor == undefined then "" else action.actor
  $("#action-label").text("#{action.type} #{actorStr}")
  dumpBoard(action.board)
  for i in [0...4]
    player = action.board.players[i]
    view = Dytem.players.at(i)
    if !player.tehais
      renderPais([], view.tehais)
      view.tsumoPai.hide()
    else if player.tehais.length % 3 == 2
      renderPais(player.tehais[0...(player.tehais.length - 1)], view.tehais)
      view.tsumoPai.show()
      renderPai(player.tehais[player.tehais.length - 1], view.tsumoPai)
    else
      renderPais(player.tehais, view.tehais)
      view.tsumoPai.hide()
    ho = player.ho || []
    renderHo(player, 0, ho[0...6], view.hoRows.at(0).pais)
    renderHo(player, 6, ho[6...12], view.hoRows.at(1).pais)
    renderHo(player, 12, ho[12...], view.hoRows.at(2).pais)
    view.furos.clear()
    if player.furos
      j = player.furos.length - 1
      while j >= 0
        furo = player.furos[j]
        furoView = view.furos.append()
        renderPai(furo.taken, furoView.taken, 3) if furo.taken
        renderPais(furo.consumed, furoView.consumed)
        --j

$ ->
  
  $("#prev-button").click ->
    return if currentActionId == 0
    --currentActionId
    $("#action-id-label").val(currentActionId)
    renderAction(loadedActions[currentActionId])
  
  $("#next-button").click ->
    return if currentActionId == loadedActions.length - 1
    ++currentActionId
    $("#action-id-label").val(currentActionId)
    renderAction(loadedActions[currentActionId])
  
  $("#go-button").click ->
    currentActionId = parseInt($("#action-id-label").val())
    renderAction(loadedActions[currentActionId])
  
  Dytem.init()
  for i in [0...4]
    playerView = Dytem.players.append()
    playerView.addClass("player-#{i}")
    for j in [0...3]
      playerView.hoRows.append()

  for action in allActions
    loadAction(action)
  console.log("loaded")
  
  #currentActionId = 78
  renderAction(loadedActions[currentActionId])
