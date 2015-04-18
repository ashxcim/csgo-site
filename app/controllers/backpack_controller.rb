class BackpackController < ApplicationController
  @backpack_list

  def index
    require 'net/http'

    api_key = ENV['steam_api_key']
    res_schema = hash_from_url('http://api.steampowered.com/IEconItems_730/GetSchema/v0002/?key=' + api_key)
    schema_attributes = res_schema['result']['attributes']
    res_player_items = hash_from_url('http://api.steampowered.com/IEconItems_730/GetPlayerItems/v0001/?key=' + api_key + '&SteamID=76561198095250703')['result']['items']
    res_player_inventory = hash_from_url('http://steamcommunity.com/id/efpies_the_only/inventory/json/730/2/?l=english')

    @backpack_list = list_items(schema_attributes, res_player_items, res_player_inventory)
  end

  def attribute(attributes, defindex)
    attributes.find {|attr| attr['defindex'] == defindex }
  end

  def wear_value(attributes)
    (attributes.find {|attr| attr['defindex'] == 8} || {})['float_value']
  end

  def is_stattrak(attributes)
    attributes.any? {|attr| attr['defindex'] == 147}
  end

  def class_instance_id(rg_items, id)
    rg_items[id.to_s]['classid'] + '_' + rg_items[id.to_s]['instanceid']
  end

  def description(descriptions, class_instance_id)
    descriptions[class_instance_id]
  end

  def inventory_item(inventory, id)
    class_instance_id = class_instance_id(inventory['rgInventory'], id)
    description = description(inventory['rgDescriptions'], class_instance_id)
    item = Hash.new

    item['icon_url'] = 'http://steamcommunity-a.akamaihd.net/economy/image/' + (description['icon_url_large'] || description['icon_url']) + '/'
    item['name'] = description['name']
    item['market_name'] = description['market_name']
    item['name_color'] = description['name_color']
    item['type'] = description['type']

    item
  end

  def is_weapon(item)
    type = item['type']

    item['type'].include?('Shotgun') || item['type'].include?('Rifle') || item['type'].include?('Machinegun') || item['type'].include?('Pistol') || item['type'].include?('SMG')
  end

  def list_items(attributes_hash, items, inventory)
    items.map { |item|
      mapped = Hash.new
      mapped['id'] = item['id']

      mapped['attributes'] = item['attributes'].map { |attr|
        schema_attr = attribute(attributes_hash, attr['defindex'])
        attr['name'] = schema_attr['name']
        attr
      }

      inventory_item = inventory_item(inventory, item['id'])

      unless is_weapon(inventory_item)
        {}
        next
      end

      mapped = mapped.merge(inventory_item)

      mapped['wear_value'] = wear_value(mapped['attributes'])
      mapped['is_stattrak'] = is_stattrak(mapped['attributes'])

      mapped
    }.select { |item| item }
  end

  def hash_from_url(url)
    url = URI.parse(url)
    req = Net::HTTP::Get.new(url.to_s)
    json_res = Net::HTTP.start(url.host, url.port) { |http|
      http.request(req)
    }

    JSON.parse(json_res.body)
  end
end
