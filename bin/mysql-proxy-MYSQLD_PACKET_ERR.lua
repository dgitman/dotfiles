function read_query( packet )
  if string.byte(packet) == proxy.COM_QUERY then
    proxy.queries:append(1, packet, {resultset_is_needed = true} )
    return proxy.PROXY_SEND_QUERY
  end
end

function read_query_result (inj)
  local res = assert(inj.resultset)
  if res.query_status == proxy.MYSQLD_PACKET_ERR then
    local out_string =
      "Time Stamp = " .. os.date('%Y-%m-%d %H:%M:%S') .. "n" ..
      "Query      = " .. inj.query .. "n" ..
      "Error Code = " .. res.raw:byte(2)+(res.raw:byte(3)*256) .. "n" ..
      "SQL State  = " .. string.format("%q", res.raw:sub(5, 9)) .. "n" ..
      "Err Msg    = " .. string.format("%q", res.raw:sub(10)) .. "n" ..
      "Default DB = " .. proxy.connection.client.default_db .. "n" ..
      "Username   = " .. proxy.connection.client.username .. "n" ..
      "Address    = " .. proxy.connection.client.src.name .. "n" ..
      "Thread ID  = " .. proxy.connection.server.thread_id .. "n"
    print(out_string .. "n")
  end
end
