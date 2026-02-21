seed_password = "password123"

admins = [
  { name: "Admin Operacao", email: "admin@comandup.local" },
  { name: "Admin Cozinha", email: "admin2@comandup.local" }
].map do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.assign_attributes(
    name: attrs[:name],
    role: :admin,
    provider: nil,
    uid: nil,
    password: seed_password,
    password_confirmation: seed_password
  )
  user.save!
  user
end

customers = [
  { name: "Cliente Balcao", email: "cliente@comandup.local" },
  { name: "Carla Menezes", email: "carla@comandup.local" },
  { name: "Rafael Lima", email: "rafael@comandup.local" },
  { name: "Juliana Costa", email: "juliana@comandup.local" },
  { name: "Pedro Souza", email: "pedro@comandup.local" },
  { name: "Marina Alves", email: "marina@comandup.local" }
].map do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.assign_attributes(
    name: attrs[:name],
    role: :customer,
    provider: nil,
    uid: nil,
    password: seed_password,
    password_confirmation: seed_password
  )
  user.save!
  user
end

products = [
  { name: "X-Burger", description: "Pão brioche, carne 150g e queijo", price_cents: 2490, prep_minutes: 12 },
  { name: "X-Salada", description: "Hambúrguer, alface, tomate e maionese da casa", price_cents: 2690, prep_minutes: 13 },
  { name: "X-Bacon", description: "Hambúrguer, bacon crocante e queijo", price_cents: 2990, prep_minutes: 14 },
  { name: "Batata Frita P", description: "Porção individual", price_cents: 1290, prep_minutes: 8 },
  { name: "Batata Frita G", description: "Porção para compartilhar", price_cents: 1890, prep_minutes: 10 },
  { name: "Onion Rings", description: "Anéis de cebola empanados", price_cents: 1690, prep_minutes: 9 },
  { name: "Refrigerante Lata", description: "350ml", price_cents: 700, prep_minutes: 2 },
  { name: "Suco Natural", description: "Copo 400ml", price_cents: 1200, prep_minutes: 4 },
  { name: "Água Mineral", description: "500ml", price_cents: 450, prep_minutes: 1 },
  { name: "Milkshake Chocolate", description: "400ml", price_cents: 1590, prep_minutes: 6 }
]

products.each do |attrs|
  product = Product.find_or_initialize_by(name: attrs[:name])
  product.assign_attributes(attrs.merge(active: true))
  product.save!
end

x_burger = Product.find_by!(name: "X-Burger")
x_bacon = Product.find_by!(name: "X-Bacon")
batata_p = Product.find_by!(name: "Batata Frita P")
refrigerante = Product.find_by!(name: "Refrigerante Lata")
suco = Product.find_by!(name: "Suco Natural")

queue_orders = [
  {
    service_token: "seed-queue-001",
    order_type: :table,
    status: :received,
    table_number: "MESA 03",
    customer: nil,
    items: [{ product: x_burger, quantity: 1 }, { product: refrigerante, quantity: 1 }]
  },
  {
    service_token: "seed-queue-002",
    order_type: :pickup,
    status: :received,
    table_number: nil,
    customer: customers[1],
    items: [{ product: x_bacon, quantity: 1 }, { product: batata_p, quantity: 1 }]
  },
  {
    service_token: "seed-queue-003",
    order_type: :delivery,
    status: :in_production,
    table_number: nil,
    delivery_address: "Rua das Flores, 123 - Centro",
    customer: customers[2],
    items: [{ product: x_burger, quantity: 2 }, { product: suco, quantity: 2 }]
  },
  {
    service_token: "seed-queue-004",
    order_type: :table,
    status: :ready,
    table_number: "MESA 08",
    customer: nil,
    items: [{ product: batata_p, quantity: 1 }, { product: refrigerante, quantity: 2 }]
  }
]

queue_orders.each do |attrs|
  order = Order.find_or_initialize_by(service_token: attrs[:service_token])
  status = attrs[:status]
  order.assign_attributes(
    customer: attrs[:customer],
    order_type: attrs[:order_type],
    status: status,
    table_number: attrs[:table_number],
    delivery_address: attrs[:delivery_address],
    received_at: (status == :received || status == :in_production || status == :ready || status == :delivered) ? Time.current : nil,
    started_at: (status == :in_production || status == :ready || status == :delivered) ? Time.current : nil,
    ready_at: (status == :ready || status == :delivered) ? Time.current : nil
  )

  subtotal = attrs[:items].sum { |item| item[:product].price_cents * item[:quantity] }
  order.subtotal_cents = subtotal
  order.discount_cents = 0
  order.total_cents = subtotal
  order.save!

  order.order_items.destroy_all
  attrs[:items].each do |item|
    qty = item[:quantity]
    unit = item[:product].price_cents
    order.order_items.create!(
      product: item[:product],
      quantity: qty,
      unit_price_cents: unit,
      total_cents: unit * qty
    )
  end
end

Orders::EtaCalculator.call

puts "Seed concluido."
puts "Admins: #{admins.map(&:email).join(', ')}"
puts "Clientes: #{customers.size} (senha padrao: #{seed_password})"
puts "Produtos: #{Product.count}"
puts "Pedidos de exemplo para fila: #{queue_orders.size}"
