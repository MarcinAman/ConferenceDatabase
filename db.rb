#!/usr/bin/env ruby

require 'tiny_tds'
require 'faker'

class Integer
  def years
    self * 24 * 60 * 60 * 365
  end

  def months
    self * 30 * 24 * 60 * 60
  end

  def days
    self * 24 * 60 * 60
  end

  def hours
    self * 60 * 60
  end

  def minutes
    self * 60
  end

  def ago
    Time.now.to_i - self
  end

  def ahead
    Time.now.to_i + self
  end

  def to_d
    DateTime.parse(Time.at(self).to_s)
  end
end

class Date
  def self.between(a, b)
    DateTime.parse(
      Time.parse(
        Faker::Date.between(a.to_d, b.to_d).to_s
      ).to_s
    )
  end

  def to_i
    to_time.to_i
  end

  def to_z
    strftime('%Y-%m-%d %H:%M:%S')
  end
end

class String
  def to_d
    DateTime.parse(self)
  end
end

def read_file(path)
  lines = []
  file = File.new(path, 'r')
  while (line = file.gets)
    lines << line
  end
  file.close
  lines
end

class Conference
  attr_accessor :id,
                :name,
                :start_time,
                :end_time,
                :discount,
                :customers,
                :workshops,
                :days
end

class Customer
  attr_accessor :id,
                :name,
                :phone,
                :NIP,
                :email,
                :address,
                :zip_code,
                :country,
                :is_company,
                :order_id,
                :orders
end

class Workshop
  attr_accessor :id,
                :conference_day_id,
                :title,
                :places,
                :price,
                :start_time,
                :end_time,
                :conference_day_id
end

Faker::Config.locale = :pl

$client = TinyTds::Client.new(
  username: 'sa',
  password: 'P@ssw0rd',
  host: '127.0.0.1',
  port: 1433,
  database: 'master',
  message_handler: proc { |m| puts m.message }
)

def exec(procedure, params, output = nil)
  params_string = params.map { |p|
    p.is_a?(Integer) || p.is_a?(Float) ? p : "'#{p}'"
  }.join(', ')

  query = 'DECLARE ' + (!output.nil? ? "@#{output} INT, " : '') + "@result INT; \
  EXEC @result = #{procedure} #{params_string}" + (!output.nil? ? ", @#{output} OUTPUT" : "") + "; \
  SELECT " + (!output.nil? ? "@#{output} as '#{output}', " : '') + "@result as 'result';"

  begin
    $client.execute(query).each
  rescue TinyTds::Error => e
    p e.inspect
    $client.close
    exit
  end
end

read_file('./ddl.sql').
  join("\n").
  split('GO').
  each { |cmd| $client.execute(cmd).do }

$rg = Random.new
$conferences = []

def generate_conference(start_time, days)
  conference = $conferences.last
  conference.customers = []
  conference.workshops = []
  conference.days = []

  conference.name =
    Faker::Company.bs.split.map(&:capitalize).join(' ') << ' Conference'
  p "Adding conference '#{conference.name}'..."
  conference.start_time = start_time.to_z
  conference.end_time = (start_time.to_i + days.days).to_d.to_z
  conference.discount = $rg.rand(5) / 10

  result = exec(
    'create_conference', [
      conference.name,
      conference.start_time,
      conference.end_time,
      conference.discount
    ], 'conference_id'
  )
  conference.id = result.first['conference_id']

  price_offset = rand(4) * 100
  rounds = (3 + rand(2))
  (0...rounds).each do |i|
    result = exec(
      'add_conference_pricing', [
        price_offset + i * 100 + 100,
        (conference.start_time.to_d.to_i - (rounds - i) * 15.days).to_d.to_z
      ], 'conference_pricing_id'
    )
    exec(
      'add_conference_has_pricing', [
        result.first['conference_pricing_id'],
        conference.id
      ]
    )
  end
  generate_days(conference, days)
end

def generate_days(conference, days)
  (0...days).each do |i|
    day = ($conferences.last.start_time.to_d.to_i + i.days).to_d.to_z
    places = $rg.rand(5) * 10 + 1000

    result = exec(
      'add_conference_day', [
        $conferences.last.id,
        day,
        places
      ], 'conference_day_id'
    )
    conference.days << {
      id: result.first['conference_day_id'],
      day: day,
      places: places
    }

    (0...$rg.rand(5)).each do |_|
      workshop = Workshop.new
      $conferences.last.workshops << workshop
      generate_workshop(days)
    end
  end
end

def generate_workshop(days)
  day_index = $rg.rand($conferences.last.days.size)
  workshop = $conferences.last.workshops.last
  workshop.title = Faker::Company.bs.capitalize
  workshop.places = rand(4) * 5 + 100
  workshop.price = rand(100) + 100
  workshop.start_time = $conferences.last.days[day_index][:day]
  workshop.end_time = (
    workshop.start_time.to_d.to_i + rand(3) * 30.minutes
  ).to_d.to_z
  workshop.conference_day_id = $conferences.last.days[day_index][:id]
  workshop.id = create_workshop(workshop, day_index)
end

def generate_customer()
  customer = $conferences.last.customers.last
  fill_customer(customer)
  customer.orders = []
  customer.id = add_customer(customer)
end

def fill_customer(customer)
  is_company = rand(2) != 0
  customer.name = is_company ? Faker::Company.name : Faker::Name.name
  customer.phone = Faker::PhoneNumber.cell_phone
  customer.NIP = '000-000-00-00'
  customer.email = Faker::Internet.email
  customer.address = Faker::Address.street_address
  customer.zip_code = Faker::Address.zip_code
  customer.country = 'Poland'
  customer.is_company = is_company
end

def create_participants(customer, places_reserved)
  participant_ids = []
  # Assign people to order items
  if customer.is_company
    (0...places_reserved).each { |_| participant_ids << add_company_participant(customer) }
  else
    participant_ids << add_solo_participant(customer)
  end
  participant_ids
end

def assign_participants(customer, workshop, participant_ids)
  participant_ids.each do |p_id|
    conference_day_participant_id = add_conference_day_participant(p_id, workshop)
    exec(
      'add_workshop_participant', [
        workshop.id,
        conference_day_participant_id,
        p_id,
        customer.order_id
      ]
    )
  end
end

def add_conference_day_participant(participant_id, workshop)
  exec(
    'add_conference_day_participant', [
      participant_id,
      workshop.conference_day_id
    ], 'conference_day_participant_id'
  ).first['conference_day_participant_id']
end

def create_workshop(workshop, day_index)
  exec(
    'create_workshop', [
      $conferences.last.days[day_index][:id],
      workshop.title,
      workshop.places,
      workshop.price,
      workshop.start_time,
      workshop.end_time
    ], 'workshop_id'
  ).first['workshop_id']
end

def add_customer(customer)
  exec(
    'add_customer', [
      customer.name,
      customer.phone,
      customer.NIP,
      customer.email,
      customer.address,
      customer.zip_code,
      customer.country,
      customer.is_company
    ], 'customer_id'
  ).first['customer_id']
end

def add_company_participant(customer)
  exec(
    'add_participant', [
      customer.id,
      customer.orders.last,
      Faker::Name.name
    ], 'participant_id'
  ).first['participant_id']
end

def add_solo_participant(customer)
  exec(
    'add_participant', [
      customer.id,
      customer.orders.last,
      customer.name
    ], 'participant_id'
  ).first['participant_id']
end

def add_order(customer)
  exec(
    'add_order', [
      customer.phone,
      customer.email
    ], 'order_id'
  ).first['order_id']
end

def add_order_item(customer, workshop, places_reserved)
  exec(
    'add_order_item', [
      customer.order_id,
      workshop.id,
      workshop.conference_day_id,
      places_reserved
    ], 'order_item_id'
  ).first['order_item_id']
end

(0...10).each do |_|
  start_time = Date.between(6.months.ahead, 3.years.ahead)
  days = $rg.rand(4) + 3

  conference = Conference.new
  $conferences << conference
  generate_conference(start_time, days)

  (0...10).each do |_|
    customer = Customer.new
    $conferences.last.customers << customer
    generate_customer
    customer.order_id = add_order(customer)

    $conferences.last.workshops.each do |w|
      next if rand(2).zero?
      places_reserved = customer.is_company ? rand(2) * 5 + 5 : 1
      customer.orders << add_order_item(customer, w, places_reserved)
      participant_ids = create_participants(customer, places_reserved)
      assign_participants(customer, w, participant_ids)
    end
  end
end

$client.close
