-- PID: BZvOcmJ1H6XtadQEiKAxKGxVO6M0WopY-Lg4U6EgPME

LatestGameState = {}
InAction = false

function inRange(x1, y1, x2, y2, range)
  return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

function decideNextAction()
  local player = LatestGameState.Players[ao.id]
  local targetInRange = false
  local bestTarget = nil
  for target, state in pairs(LatestGameState.Players) do
    if target ~= ao.id and inRange(player.x, player.y, state.x, state.y, 1) then
      targetInRange = true
      if not bestTarget or state.health < bestTarget.health or (state.health == bestTarget.health and inRange(player.x, player.y, state.x, state.y, 1) < inRange(player.x, player.y, bestTarget.x, bestTarget.y, 1)) then
        bestTarget = state
      end
    end
  end

  if player.energy > 5 and targetInRange then
    print("Player in range. Attacking.")
    ao.send({
      Target = Game,
      Action = "PlayerAttack",
      Player = ao.id,
      AttackEnergy = tostring(player.energy),
    })
    print("No player in range or low energy. Moving randomly.")

    local directionRandom = { "Up", "Down", "Left", "Right" }
    local randomIndex = math.random(#directionRandom)
    ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionRandom[randomIndex] })
  end
  InAction = false
end

Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function(msg)
    if msg.Event == "Started-Waiting-Period" then
      ao.send({ Target = ao.id, Action = "AutoPay" })
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
      InAction = true
      ao.send({ Target = Game, Action = "GetGameState" })
    elseif InAction then
      print("Previous action still in progress. Skipping.")
    end
    print(msg.Event .. ": " .. msg.Data)
  end
)

Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function()
    if not InAction then
      InAction = true
      print("Getting game state...")
      ao.send({ Target = Game, Action = "GetGameState" })
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)

Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "AutoPay"),
  function(msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
  end
)

Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function(msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({ Target = ao.id, Action = "UpdatedGameState" })
    print("Game state updated. Print \'LatestGameState\' for detailed view.")
  end
)

Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function()
    if LatestGameState.GameMode ~= "Playing" then
      InAction = false
      return
    end
    print("Deciding next action.")
    decideNextAction()
    ao.send({ Target = ao.id, Action = "Tick" })
  end
)

Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function(msg)
    if not InAction then
      InAction = true
      local playerEnergy = LatestGameState.Players[ao.id].energy
      if playerEnergy == undefined then
        print("Unable to read energy.")
        ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
      elseif playerEnergy == 0 then
        print("Player has insufficient energy.")
        ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
      else
        print("Returning attack.")
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
      end
      InAction = false
      ao.send({ Target = ao.id, Action = "Tick" })
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)
