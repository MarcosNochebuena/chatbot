require_relative "../services/whatsapp_bot"
class MessagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  def create
    if params["MessageType"] == "text" && params["Body"].present? && params["From"].present?
      user_message = params["Body"]
      from_number = params["From"]

      # Recupera o crea una conversación
      conversation = find_or_create_conversation(from_number)

      # Procesa el mensaje y genera la respuesta
      response_message = handle_message(conversation, user_message, from_number)

      # Envía la respuesta al cliente
      MessageSender.send(to: from_number, body: response_message)
      render json: { status: "success" }, status: :ok
    elsif params["MessageStatus"].present?
      Rails.logger.info("Message status update: #{params['MessageStatus']}")
      head :ok
    else
      head :bad_request
    end
  end

  private

  def handle_message(conversation, user_message, phone)
    # Recupera el contexto y los slots de la conversación
    context = conversation[:context] || []
    slots = conversation[:slots] || initialize_slots

    # Agrega el nuevo mensaje del usuario al contexto
    context << { role: "user", content: user_message }

    # Genera la respuesta del bot
    response = WhatsAppBot.generate_response(user_message, context)

    # Extrae entidades del mensaje del usuario y parsea el JSON a un hash
    extracted_data = WhatsAppBot.extract_entities_from_message(user_message)

    # Actualiza los slots con los datos extraídos del mensaje
    puts "Extracted data: #{extracted_data}"
    extracted_data.each do |key, value|
      puts "Key: #{key}, Value: #{value}"
      slots[key.to_sym] ||= value unless value.nil?
    end

    # Agrega la respuesta del asistente al contexto
    context << { role: "assistant", content: response }

    # Actualiza la conversación en Redis con el nuevo contexto y slots
    conversation[:context] = context
    conversation[:slots] = slots
    Rails.cache.write(conversation[:id], conversation, expires_in: 30.minutes)

    # Detecta si el pedido está completo y responde adecuadamente
    puts "Slots: #{slots}"
    if order_complete?(slots)
      confirmation_message = format_order_details(slots)
      save_order_to_db(slots, phone) # Opcional: guarda el pedido en la base de datos
      Rails.cache.delete(conversation[:id]) # Limpia la conversación una vez completada
      confirmation_message
    else
      # Pregunta por los datos que faltan
      response
    end
  end


  def find_or_create_conversation(phone)
    Rails.cache.fetch(phone, expires_in: 30.minutes) do
      {
        id: phone,
        context: [
          { role: "system", content: "Eres un asistente para agendar pedidos. Solicita información como nombre, fecha, hora, artículos, ubicación y dirección." }
        ],
        slots: initialize_slots
      }
    end
  end

  def initialize_slots
    {
      name: nil,
      delivery_date: nil,
      delivery_time: nil,
      items: nil,
      address: nil
    }
  end

  def order_complete?(slots)
    slots.values.all?
  end

  def format_order_details(order)
    <<~MESSAGE
      ¡Tu pedido está completo! Aquí están los detalles:

      📝 **Nombre:** #{order[:name] || 'No especificado'}
      📅 **Fecha de entrega:** #{order[:delivery_date] || 'No especificada'}
      ⏰ **Hora de entrega:** #{order[:delivery_time] || 'No especificada'}
      📍 **Dirección:** #{order[:address] || 'No especificada'}
      🛒 **Artículos solicitados:** #{order[:items].presence || 'No especificados'}

      ¡Gracias por confiar en nosotros! 😊
    MESSAGE
  end


  def save_order_to_db(order, phone)
    Order.create(
      phone: phone,
      name: order[:name],
      delivery_date: Date.parse(order[:delivery_date]),
      delivery_time: Time.parse(order[:delivery_time]),
      items: order[:items],
      address: order[:address],
      status: "pending"
    )
  end
end
