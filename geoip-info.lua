function ipv4split(ip)
  local list = {}
  local pos = 1
  local delim = "%."

  while true do
    local first, last = string.find(ip, delim, pos);
    if first then
      list[#list+1] = string.sub(ip, pos, first-1);
      pos = last+1;
    else
      list[#list+1] = string.sub(ip, pos);
      break;
    end
  end

  return list;
end

function ipv4reverse(ip)
  if type(ip) ~= "string" then return nil end

  local ip_parts = ipv4split(ip)
  if type(ip_parts) == "table" and #ip_parts > 5 then
    ip_parts = {unpack(ip_parts, 1,4)}
  else
    return nil
  end
  local ip_reverse = {}
  for i = #ip_parts, 1, -1 do
    if tonumber(ip_parts[i]) and ( tonumber(ip_parts[i]) > -1 and tonumber(ip_parts[i]) < 256 ) then
      table.insert(ip_reverse, ip_parts[i])
    else
      return nil
    end
  end

  return table.concat(ip_reverse, ".")
end

function isipv4(ip)
  if type(ip) ~= "string" then return false end

  local ip_parts = ipv4split(ip)
  if type(ip_parts) == "table" and #ip_parts > 5 then
    ip_parts = {unpack(ip_parts, 1,4)}
  else
    return false
  end
  for k,v in ipairs(ip_parts) do
    if not ( tonumber(v) and ( tonumber(v) > -1 and tonumber(v) < 256 ) ) then
      return false
    end
  end

  return table.concat(ip_parts, ".")
end


function preresolve(dq)
  if dq.qtype == pdns.TXT then
    local direct_ip = nil
    local cntlabels = dq.qname:countLabels()
    if (dq.qname:isPartOf(newDN("rbl.example.com")) and (cntlabels == 7 or cntlabels == 8)) then
      if (dq.qname:isPartOf(newDN("direct.rbl.example.com"))) then
        direct_ip = isipv4(dq.qname:toString())
      else
        direct_ip = ipv4reverse(dq.qname:toString())
      end
      if not direct_ip then
        dq.rcode = pdns.NXDOMAIN
        return true
      end

      local mmdb = require "mmdb"
      local geo_country_db = mmdb.read("/usr/local/eoLite2-Country.mmdb") or nil
      local geo_asn_db = mmdb.read("/usr/local/GeoLite2-ASN.mmdb") or nil

      if not geo_country_db or not geo_asn_db then
        pdnslog("Error opening mmdb database files", pdns.loglevels.Warning)
        dq.rcode = pdns.SERVFAIL
        return true
      end

      local country_data = geo_country_db:search_ipv4(direct_ip)
      local asn_data = geo_asn_db:search_ipv4(direct_ip)

      local continent = nil
      local country = nil
      local reg_country = nil
      local asn_number = nil
      local asn_org = nil
      if type(country_data) == "table" then
        if country_data["country"] and country_data["continent"] then
          country = country_data["country"]["iso_code"] or nil
          continent = country_data["continent"]["code"] or nil
        end
        if country_data["registered_country"] then
          reg_country = country_data["registered_country"]["iso_code"] or country
        end
      end

      if type(asn_data) == "table" then
        asn_number = asn_data["autonomous_system_number"] or nil
        asn_org = asn_data["autonomous_system_organization"] or "Unknown"
      end

      if dq.qname:isPartOf(newDN("asn.rbl.example.com")) and asn_number then
        dq.rcode = pdns.NOERROR
        dq:addAnswer(pdns.TXT, '"' .. tostring(asn_number) .. '"', 60)
        return true
      elseif dq.qname:isPartOf(newDN("country.rbl.example.com")) and country then
        dq.rcode = pdns.NOERROR
        dq:addAnswer(pdns.TXT, '"' .. tostring(country) .. '"', 60)
        return true
      elseif dq.qname:isPartOf(newDN("continent.rbl.example.com")) and continent then
        dq.rcode = pdns.NOERROR
        dq:addAnswer(pdns.TXT, '"' .. tostring(continent) .. '"', 60)
        return true
      elseif country and continent and reg_country and asn_number and asn_org then
        local res = tostring(asn_number) .. "|" .. direct_ip .. "/32" .. "|" .. tostring(country) .. "|" .. tostring(continent) .. "|" .. tostring(reg_country) .. "|" .. tostring(asn_org)
        dq.rcode = pdns.NOERROR
        dq:addAnswer(pdns.TXT, '"' .. res .. '"', 60)
        return true
      end
    end
  end

	dq.rcode = pdns.NXDOMAIN
	return true
end
