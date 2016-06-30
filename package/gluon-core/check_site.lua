need_string 'site_code'
need_string 'site_name'

if need_table('opkg', nil, false) then
  need_string('opkg.openwrt', false)

  function check_repo(k, _)
    -- this is not actually a uci name, but using the same naming rules here is fine
    assert_uci_name(k)

    need_string(string.format('opkg.extra[%q]', k))
  end

  need_table('opkg.extra', check_repo, false)
end

need_string('hostname_prefix', false)
need_string 'timezone'

need_string_array('ntp_servers', false)

need_string_match('prefix4', '^%d+.%d+.%d+.%d+/%d+$')
need_string_match('prefix6', '^[%x:]+/%d+$')


for _, config in ipairs({'wifi24', 'wifi5'}) do
  if need_table(config, nil, false) then
    need_string('regdom') -- regdom is only required when wifi24 or wifi5 is configured

    need_number(config .. '.channel')

    function var_in_array(var, array)
      for _,v in ipairs(array) do
        if v == var then
          return true
        end
      end
      return false
    end

    function check_rate(var)
      rates={1000, 2000, 5500, 6000, 9000, 11000, 12000, 18000, 24000, 36000, 48000, 54000}
      assert(var_in_array(var, rates),"site.conf error: `" .. var .. "' is not a valid wifi rate.")
      return var
    end

    if need_array(config .. '.supported_rates', check_rate, false) then
      need_array(config .. '.basic_rate',check_rate, true)
    else
      need_array(config .. '.basic_rate', check_rate, false)
    end
  end
end
