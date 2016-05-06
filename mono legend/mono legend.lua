numLanes = 5


halfLanes = 0
oddNumLanes = true
if numLanes % 2 == 0 then
	oddNumLanes = false
	halfLanes = numLanes / 2
else
	oddNumLanes = true
	halfLanes = (numLanes -1) / 2
end

GameplaySettings{
		usepuzzlegrid = false,
        greypercent=0,
        colorcount=1,
        usetraffic = true,
        automatic_traffic_collisions = false, -- the game shouldn't check for block collisions since we'll be doing that ourselves in this script
        jumpmode="none",
        matchcollectionseconds=1.5,
        greyaction="normal", -- "eraseall"  -- "eraseblock"
		usecaterpillars = false,
		trafficCompression = 1,
		--track generation settings
		gravity=-.65,
        playerminspeed = 0.1,--so the player is always moving somewhat
        playermaxspeed = 5.0,--2.9
        minimumbestjumptime = 2.5,--massage the track until a jump of at least this duration is possible
        uphilltiltscaler = 2.0,--1.5,--set to 1 for a less extreme track
        downhilltiltscaler = 2.0,--1.5,--set to 1 for a less extreme track
        uphilltiltsmoother = 0.06,
        downhilltiltsmoother = 0.06,
        useadvancedsteepalgorithm = true,--set false for a less extreme track
        alldownhill = false,
		calculate_antijumps_and_antitraffic = false
		--end track generation settings
		
        --trafficcompression=.5,
}
if oddNumLanes then
	SetSkinProperties{
		lanedividers={-7.5,-4.5,-1.5,1.5,4.5,7.5},
		shoulderlines={-11.0,11.0},
		trackwidth = 11.5
	}
else
	SetSkinProperties{
		lanedividers={-6,-3,0,3,6},
		shoulderlines={-11.0,11.0},
		trackwidth = 11.5
	}
end

function deepcopy(orig) -- a pretty standard lua function for making a copy of a table
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

if not players then --create the players if they haven't been created yet
	players = {}
	players[1]={
		score=0,
		prevInput={},
		iPrevRing=0,
		hasFinishedScoringPrevRing=false,
		uniqueName = "Right",
		num=1,
		prevFirstBlockCollisionTested = 1,
		pos = {0,0,1.5},
		posCosmetic = {0,0,1.5},
		controller = "mouse",
		points = 0, -- used for accumulating points this player earns at each match collection. temp var
		lane = 0
	}
end

function CompareJumpTimes(a,b) --used to sort the track nodes by jump duration
	return a.jumpairtime > b.jumpairtime
end

function CompareAntiJumpTimes(a,b) --used to sort the track nodes by jump duration
	return a.antiairtime > b.antiairtime
end

powernodes = powernodes or {}
antinodes = antinodes or {}
lowestaltitude = 9999
highestaltitude = -9999
lowestaltitude_node = 0
highestaltitude_node = 0
--onTrackCreatedHasBeenCalled = false
longestJump = longestJump or -1
track = track or {}

function OnTrackCreated(theTrack)--track is created before the traffic
	track = theTrack --store a global copy of the track to maybe use later
	-- when you return a track table from this function the game will read and apply any changes you made
    
	local songMinutes = track[#track].seconds / 60

	for i=1,#track do
		track[i].jumpedOver = false -- if this node was jumped over by a higher proiority jump
		track[i].origIndex = i
		track[i].antiOver = false
	end

	--find the best jumps path in this song
	local strack = deepcopy(track)
	table.sort(strack, CompareJumpTimes)

	print("POWERNODE calculations. Best air time "..strack[1].jumpairtime)

	for i=1,#strack do
--		if strack[i].origIndex > 300 then
		if strack[i].jumpairtime >= 2.5 then --only consider jumps of at least this amount of air time
			longestJump = math.max(longestJump, strack[i].jumpairtime)
			--print("POWERNODE airtime"..strack[i].jumpairtime)
			if not track[strack[i].origIndex].jumpedOver then
				local flightPathClear = true
				local jumpEndSeconds = strack[i].seconds + strack[i].jumpairtime + 10
				for j=strack[i].origIndex, #track do --make sure a higher priority jump doesn't happen while this one would be airborne
					if track[j].seconds <= jumpEndSeconds then
						if track[j].jumpedOver then
							flightPathClear = false
						end
					else
						break
					end
				end
				if flightPathClear then
					if #powernodes < (songMinutes * 3) then -- allow about one power node per minute of music
						if strack[i].origIndex > 300 then
							powernodes[#powernodes+1] = strack[i].origIndex
							print("added powernode at ring "..strack[i].origIndex)
						end
						local extraJumpOverBufferSec = 10
						jumpEndSeconds = strack[i].seconds + strack[i].jumpairtime + extraJumpOverBufferSec
						for j=strack[i].origIndex, #track do
							if track[j].seconds <= jumpEndSeconds then
								track[j].jumpedOver = true --mark this node as jumped over (a better jump took priority) so it is not marked as a powernode
							else
								break
							end
						end
					end
				end
			end
		end

		if strack[i].pos.y > highestaltitude then
			highestaltitude = strack[i].pos.y
			highestaltitude_node = i
		end
		if strack[i].pos.y < lowestaltitude then
			lowestaltitude = strack[i].pos.y
			lowestaltitude_node = i
		end
	end

	if calcAntiJumps then
		table.sort(strack, CompareAntiJumpTimes)
		for i=1,#strack do
			--if strack[i].antitrafficstrength > 0 then
			if strack[i].antiairtime >= 2.5 then --only consider jumps of at least this amount of air time
				--print("ANTINODE antiairtime"..strack[i].antiairtime)
				if not track[strack[i].origIndex].antiOver then
					local flightPathClear = true
					local jumpEndSeconds = strack[i].seconds + strack[i].antiairtime + 10
					for j=strack[i].origIndex, #track do --make sure a higher priority jump doesn't happen while this one would be airborne
						if track[j].seconds <= jumpEndSeconds then
							if track[j].antiOver then
								flightPathClear = false
							end
						else
							break
						end
					end
					if flightPathClear then
						if #antinodes < (songMinutes + 1) then -- allow about one power node per minute of music
							if strack[i].origIndex > 300 then
								antinodes[#antinodes+1] = strack[i].origIndex
								--print("added powernode at ring "..strack[i].origIndex)
							end
							jumpEndSeconds = strack[i].seconds + strack[i].antiairtime + 10
							for j=strack[i].origIndex, #track do
								if track[j].seconds <= jumpEndSeconds then
									track[j].antiOver = true --mark this node as jumped over (a better jump took priority) so it is not marked as a powernode
								else
									break
								end
							end
						end
					end
				end
			end
		end
	end

--	print("ontrackcreated. num powernodes "..#powernodes)
end

lanespace = 3
half_lanespace = 1.5

blocks = blocks or {}
blockNodes = blockNodes or {}
blockOffsets = blockOffsets or {}
blockColors = blockColors or {}

function OnTrafficCreated(theTraffic)
	half_lanespace = lanespace / 2

	traffic = theTraffic
    
    local minimapMarkers = {}
	for j=1,#powernodes do --insert powernodes into the traffic
		local prev = 2
		for i=prev, #traffic do
			--if traffic[i].impactnode >= powernodes[j] then
			if traffic[i].chainend >= powernodes[j] then
				--if traffic[i].impactnode == powernodes[j] then
				if traffic[i].chainstart <= powernodes[j] then
					traffic[i].powerupname = "powerpellet"
					traffic[i].type = 101 -- replace the block already at this node with a power pellet. 101 as a type doesn't mean anything to the game, but the script uses it
					traffic[i].powerRating = j
				else
					table.insert(traffic, i, {powerupname="powerpellet", type=101, impactnode=powernodes[j], chainstart=powernodes[j], chainend=powernodes[j], lane=0, strafe=0, strength=10, powerRating=j})
				end
				prev = i

				table.insert(minimapMarkers, {tracknode=powernodes[j], startheight=0, endheight=fif(j==1, 15, 11), color=fif(j==1, {233,233,233}, nil) })
				break
			end
		end
	end
    
    AddMinimapMarkers(minimapMarkers)

    for i = 1, #traffic do
    	local lane = 0
    	if oddNumLanes then
    		lane = math.random(-halfLanes,halfLanes)
    	else
    		while lane == 0 do -- with an even lane count there is no center lane, so loop until we get a nonzero lane
    			lane = math.random(-halfLanes,halfLanes)
    		end
    	end
    	traffic[i].lane = lane

    	local strafe = lane*lanespace
    	if not oddNumLanes then
	    	if strafe < 0 then strafe = strafe + half_lanespace
	    	else strafe = strafe - half_lanespace end
	    end

    	traffic[i].strafe = strafe
    	local offset = {strafe,0,0}
		local block = {}
		block.lane = lane
		block.hidden = false
		block.collisiontestcount = 0
		block.tested = {}
		for j=1,#players do
			block.tested[j] = false
		end
		block.type = traffic[i].type
		blocks[#blocks+1]=block
		blockNodes[#blockNodes+1] = traffic[i].impactnode
		blockOffsets[#blockOffsets+1] = offset
		blockColors[#blockColors+1] = track[traffic[i].impactnode].color
--    	end
    end

    return traffic -- when you return a traffic table from this function the game will read and apply any changes you made
end

function InsertLoopyLoop(theTrack, apexNode, circumference)
	circumference = math.floor(circumference)
	apexNode = math.floor(apexNode)
    local halfSize = math.floor(circumference / 2)

    if (apexNode < halfSize) or ((apexNode + halfSize) > #theTrack) then
    	return theTrack
    end

    local startRing = math.max(1,apexNode - halfSize)
    local endRing = math.min(#theTrack, apexNode + halfSize)
    local span = endRing - startRing
    local startTilt = theTrack[startRing].tilt
    local endOriginalTilt = theTrack[endRing].tilt
    local endOriginalPan = theTrack[endRing].pan
    local tiltDeltaOverEntireLoop = -360 + (endOriginalTilt - startTilt)
    local startPan = theTrack[startRing].pan
    local pan = startPan

	local panConstant = 40 -- make this number bigger if you have problems with loops running into themselves
    local panRate = panConstant / halfSize

    local panRejoinSpan = math.max(circumference*2, 200)
    local panRejoinNode = math.min(#theTrack, endRing + panRejoinSpan)

    if theTrack[panRejoinNode].pan > startPan then
    	panRate = -panRate -- the loop should bend towards the future track segments naturally
    end

    local midRing = startRing + halfSize + math.ceil(halfSize/10)

    for i = startRing+1, endRing do
        theTrack[i].tilt = startTilt + tiltDeltaOverEntireLoop * ((i - startRing) / span)

        if i==midRing then panRate = -panRate end

        pan = pan + panRate -- pan just a little while looping to make sure it doesn't run into itself
        theTrack[i].pan = pan
    end

    local panDeltaCascade = theTrack[endRing].pan - endOriginalPan
    local tiltDeltaCascade = theTrack[endRing].tilt - endOriginalTilt;
    for i = endRing + 1, #theTrack do
        theTrack[i].tilt = theTrack[i].tilt + tiltDeltaCascade
        theTrack[i].pan = theTrack[i].pan + panDeltaCascade
        theTrack[i].funkyrot = true
    end

    return theTrack
end

function InsertCorkscrew(theTrack, startNode, endNode)
	startNode = math.floor(startNode)
	endNode = math.floor(endNode)

	if endNode < #theTrack then
		local cumulativeRoll = theTrack[startNode].roll
		local rollIncrement = 360 / (endNode-startNode)
		--print("endNode:"..endNode)
		local endOriginalRoll = theTrack[endNode].roll

	    for i = startNode, endNode do
	        theTrack[i].roll = cumulativeRoll
	    	cumulativeRoll = cumulativeRoll + rollIncrement
	    	theTrack[i].funkyrot = true
	    end

	    local rollDeltaCascade = theTrack[endNode].roll - endOriginalRoll

	    for i = endNode + 1, #theTrack do
	        theTrack[i].roll = theTrack[i].roll + rollDeltaCascade
	    end
	end

    return theTrack
end

function OnRequestTrackReshaping(theTrack) -- put a loop at each powerpellet to make them easier to see coming
	--local track2 = theTrack
	--print("onrequesttrackreshaping. num powernodes "..#powernodes)

	for i=1,#powernodes do
		local size = 100 + 100 * math.max(1,(theTrack[powernodes[i]].jumpairtime / 10))
		theTrack = InsertLoopyLoop(theTrack, powernodes[i], size*0.5)
		if i==1 then--double twist on the strongest loop
			local quickscrewsize = 25
			theTrack = InsertCorkscrew(theTrack, powernodes[i], powernodes[i]+quickscrewsize+size*.5)
		elseif i==#powernodes then
			--no twist on the weakest loop
		else
			theTrack = InsertCorkscrew(theTrack, powernodes[i], powernodes[i]+size*.5)
		end
	end

	track = theTrack
	return track
end

function OnSkinLoaded()-- called after OnTrafficCreated. The skin script has loaded content.
	CreateClone{name=players[1].uniqueName, prefabName="Vehicle", attachToTrackWithNodeOffset=-1, transform={pos=players[1].pos}}

	SetPuzzle{trackoffset=-.25}

	HideBuiltinPlayerObjects() -- hide the game-controlled vehicle since we're using script-controlled vehicles instead. Also hides the game-controlled surfer

	SetScoreboardNote{text="100% - Legend"}
	SetGlobalScore{score=score}

	SetCamera{ -- calling this function (even just once) overrides the camera settings from the skin script
		nearcam={
			pos={0,1,-4},
			rot={38,0,0},
			strafiness = 0
		},
		farcam={
			pos={0,12.8,-3.5},
			rot={41,0,0},
			strafiness = 0
		}
	}
end

score = 0 --the global score shared by all players co-operatively
numBlocks = 0

function OnPuzzleCollecting()
end

iCurrentRing = 0 --Update function keeps this current
blocksToHide = {}
legendary = true
stealthy = true

function Collide(player, tracklocation)
	local strafe = player.pos[1]
	local playerLane = 0;

	local absStrafe = math.abs(strafe)

	if oddNumLanes then
		for i=2,0,-1 do
			if absStrafe > ((lanespace * i) + half_lanespace) then
				playerLane = i+1
				break
			end
		end
	else
		if absStrafe > lanespace * 2 then playerLane = 3 --a player in lane 3 is on the shoulder and will not collide with any blocks
		elseif absStrafe > lanespace * 1 then playerLane = 2
		else playerLane = 1 end
	end

	if strafe < 0 then
		playerLane = -playerLane
	end
	
	local collisionTolerenceAhead = .1
	local collisionToleranceBehind_colors = .9

	local maxRing = iCurrentRing + 20
	local foundFirst = false
	for i=player.prevFirstBlockCollisionTested,#blockNodes do
		if not blocks[i].tested[player.num] then
			if blockNodes[i] <= maxRing then
				if not foundFirst then
					player.prevFirstBlockCollisionTested = i
					foundFirst = true
				end
				
				local allowCollision = false

				local collisionToleranceBehind = (blocks[i].type == 5) and collisionToleranceBehind_greys or collisionToleranceBehind_colors

				if blockNodes[i] < (tracklocation - collisionToleranceBehind) then
					if blocks[i].collisiontestcount < 1 then
						allowCollision = true -- make sure each block is allowed at least one collision test, no matter how far behind the impact node it is now
					end
					blocks[i].irrelevant = true
				end

				if (blockNodes[i] <= (tracklocation + collisionTolerenceAhead)) and (blockNodes[i] >= (tracklocation - collisionToleranceBehind)) then
					allowCollision = true
				end

				if allowCollision then
					blocks[i].collisiontestcount = blocks[i].collisiontestcount + 1
					if not blocks[i].hidden then
						numBlocks = numBlocks + 1
						if blocks[i].lane == playerLane then
							blocksToHide[#blocksToHide+1] = i
							blocks[i].hidden = true

							local blockOffset = blockOffsets[i]
							
							score = score + 1
							SetGlobalScore{score=score,showdelta=false}
						else
							if legendary then
								legendary = false
							end
						end
						
						local scoreBoardNote = ""
						
						if legendary then
							scoreBoardNote = "Legend"
						else 
							local hitRate = math.floor((score / numBlocks) * 100 + 0.5);
							scoreBoardNote = hitRate.."%"
						end
						
						SetScoreboardNote{text=scoreBoardNote}
						SendCommand{command="HoverUp"}
					end
					blocks[i].tested[player.num] = true
				end
			else
				break --stop the loop once we get to a block way past the player
			end
			--end
		end
	end
	
end

mouseSpeed = .42
cosmeticStrafeSpeed = 15
maxStrafe = halfLanes * 3
if not oddNumLanes then
	maxStrafe = maxStrafe - 1.5
end

function UpdatePlayer(player, tracklocation, input, dt, player1_rightStick, keys)
	--print("Vertical:"..input["Vertical"])
	local mouseInput = input["mouse"]
	local mouseHorizontal = mouseInput["x"]
	local keyHorizontal = input["Horizontal"]
	local prevKeyHorizontal = player.prevInput["Horizontal"]

	if(player.controller=="mouse") then
		if keyHorizontal ~= 0 then
			player.controller = "key"
		end
	elseif mouseHorizontal~=0 then
		if player.num==1 then -- only player1 has the option of mouse control
			player.controller = "mouse"
		end
	end

	if player.controller=="mouse" then
		if dt>0 then --don't move when the game is paused
			player.pos[1] = math.min(maxStrafe, math.max(-maxStrafe, player.pos[1] + mouseHorizontal * mouseSpeed))
		end

		player.posCosmetic[1] = player.pos[1]
	else --key mode (keyboard or gamepad)

		if keyHorizontal > 0.5 and prevKeyHorizontal <= 0.5 then 
			player.lane = player.lane + 1
		elseif keyHorizontal < -0.5 and prevKeyHorizontal >= -0.5 then
			player.lane = player.lane - 1 
		end

		if player.lane > halfLanes then
			player.lane = halfLanes
		elseif player.lane < -halfLanes then
			player.lane = -halfLanes
		elseif player.lane == 0 and not oddNumLanes then
			if keyHorizontal > 0.5 and prevKeyHorizontal <= 0.5 then 
				player.lane = player.lane + 1
			elseif keyHorizontal < -0.5 and prevKeyHorizontal >= -0.5 then
				player.lane = player.lane - 1 
			end
		end

		player.pos[1] = lanespace * player.lane
		if not oddNumLanes then
    		if player.pos[1] < 0 then player.pos[1] = player.pos[1] + half_lanespace
    		else player.pos[1] = player.pos[1] - half_lanespace end
    	end

		player.posCosmetic[1] = player.posCosmetic[1] + cosmeticStrafeSpeed * dt * (player.pos[1] - player.posCosmetic[1])
	end

	SendCommand{command="SetTransform", name=player.uniqueName, param={pos=player.posCosmetic}}

	Collide(player, tracklocation)

	player.prevInput = input
end

percentPuzzleFilled = 0
quarterSecondCounter = 0
function UpdateEachQuarterSecond() -- for things that need to run regularly, but not every frame
	-- local puzzle = GetPuzzle()
	-- local cells = puzzle["cells"]
	-- local numFilled = 0
	-- local numCells = 0
	-- for colnum=1,#cells do
		-- local col = cells[colnum]
		-- for rownum=1,#col do
			-- numCells = numCells + 1
			-- local cell = col[rownum]
			-- if cell.type >=0 then
				-- numFilled = numFilled + 1
			-- end
		-- end
	-- end

	-- percentPuzzleFilled = numFilled / numCells
end

function Update(dt, tracklocation, playerstrafe, input) --called every frame
	iCurrentRing = math.floor(tracklocation)
	local playersInput = input["players"]

	blocksToHide = {}

	local player1_input = playersInput[1]
	local player1_rightStick = player1_input["Horizontal2"]

	for i=1,#players do
		UpdatePlayer(players[i], tracklocation, playersInput[i], dt, player1_rightStick, input["keyboard"])
	end

	if #blocksToHide > 0 then
		HideTraffic(blocksToHide)
		local hiddenBlockID = blocksToHide[1]
		local blockType = blocks[hiddenBlockID].type
		FlashAirDebris{colorID=fif(blockType>100, 5, blockType), duration = fif(blockType>100, 0.5, .05), sizescaler = fif(blockType>100, 5, 2)}
	end

	quarterSecondCounter = quarterSecondCounter + dt
	if quarterSecondCounter>.25 then
		quarterSecondCounter = 0 -- quarterSecondCounter - .25
		-- UpdateEachQuarterSecond()
	end
end

function GetPercentPuzzleFilled(countMatchedCellsAsEmpty)
	local puzzle = GetPuzzle()
	local cells = puzzle["cells"]
	local numFilled = 0
	local numCells = 0;
	for colnum=1,#cells do
		local col = cells[colnum]
		for rownum=1,#col do
			numCells = numCells + 1
			local cell = col[rownum]
			if cell.type >=0 then
				if not (countMatchedCellsAsEmpty and cell["matched"]) then
					numFilled = numFilled + 1
				end
			end
		end
	end

	return numFilled / numCells
end

function OnRequestFinalScoring()
	local legendBonus = 0
	if legendary then legendBonus = 9000 end
	
	local hitRate = math.floor((score / numBlocks) * 100 + 0.5)
	
	return {
		rawscore = score,
		bonuses = {
			"Legend Bonus: "..legendBonus,
			"Hit Rate: "..hitRate.."%"
		},
		finalscore = score + legendBonus
	}
end