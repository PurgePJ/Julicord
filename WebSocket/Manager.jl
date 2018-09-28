module WSManager
    include("./Logger.jl")
    using Base
    using Dates
    using OpenTrick
    using .WSLogger

    import WebSockets
    import JSON

    include("../Utils/Constants.jl")
    include("Handler.jl")

    import .Constants
    import .WSHandler


    # Establish a WebSocket connection to Discord
    function start(client)
        # ERROR: LoadError: SystemError: opening file wss://gateway.discord.gg/?v=6&encoding=json: Invalid argument
        connection = opentrick(WebSockets.open, "$(Constants.WebSocketDetails["url"])$(Constants.WebSocketDetails["path"])")
        heartbeatInterval = extractHeartbeat(connection)

        # Special payload for the heartbeat
        heartbeatPayload = Constants.heartbeatPayload

        # Start the eventloop / event chain and start the
        @async eventLoop(connection)

        #identify to the WebSocket
        identify(client, connection)

        # Start the heartbeat loop
        heartbeatLoop(sendHeartbeat, heartbeatInterval, connection, heartbeatPayload)

    end

    # Extract the heartbeat interval
    function extractHeartbeat(connection::OpenTrick.IOWrapper)
        processedData = connection |> read |> String |> JSON.parse
        return processedData["d"]["heartbeat_interval"]
    end

    # Make it under this scope since we don't want people to mess with the heartbeat loop.
    function heartbeatLoop(cb::Function, ms::Int64, connection::OpenTrick.IOWrapper, payload::Dict)
        println("Started loop")
        Base.sleep(ms / 1000)
        # Pass the cb to the function since it loops so when this function will execute again it will have a cb argument.
        cb(ms, connection, payload)
    end

    function sendHeartbeat(ms::Int64, connection::OpenTrick.IOWrapper, payload::Dict)
        parsedPayload = payload |> JSON.json #Parse the payload back to JSON
        @async write(connection, parsedPayload)
        log("Sent heartbeat successfully to the WS", "Debug")
        heartbeatLoop(sendHeartbeat, ms, connection, payload)
    end

    function eventLoop(connection::OpenTrick.IOWrapper)
        while isopen(connection)
            parsedData = connection |> read |> String |> JSON.parse
            println(parsedData["op"]) # We will call handleEvent after we manage to debug this. what do we need to debug
            if parsedData["op"] != 11
                println(parsedData["t"])
                @async WSHandler.handleEvent(parsedData)
            end
        end
    end

    function identify(client, connection::OpenTrick.IOWrapper)
        parsedIdentify = Constants.identifyDict(client.token) |> JSON.json
        write(connection, parsedIdentify)
    end
end