require_relative "../services/whatsapp_bot"
class MessagesController < ApplicationController
  def create
    if params["MessageType"] == "text" && params["Body"].present? && params["From"].present?
      user_message = params["Body"]
      from_number = params["From"]

      # Recupera o crea una conversación
      conversation = find_or_create_conversation(from_number)

      # Procesa el mensaje y genera la respuesta
      response_message = handle_message(conversation, user_message)

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

  def handle_message(conversation, user_message)
    # Contexto acumulado
    context = conversation[:context] || []
    order = conversation[:order] || initialize_order

    # Agrega el mensaje del usuario al contexto
    context << { role: "user", content: user_message }

    response_data = WhatsAppBot.generate_response_with_data_extraction(context, order)

    bot_message = response_data[:message]
    context << { role: "assistant", content: bot_message }

    update_order_from_extracted_data(order, response_data[:extracted_data])
    puts response_data[:extracted_data]

    if response_data[:extracted_data]["pedido_completo"]
      save_order_to_db(order, conversation[:id])
      response_message = "¡Tu pedido ha sido registrado exitosamente! Gracias por confiar en nosotros."
      conversation[:order] = nil
    else
      response_message = bot_message
      conversation[:order] = order
    end

    conversation[:context] = context
    Rails.cache.write(conversation[:id], conversation, expires_in: 30.minutes)

    response_message
  end


  def find_or_create_conversation(phone)
    Rails.cache.fetch(phone, expires_in: 30.minutes) do
      {
        id: phone,
        context: [
          { role: "system", content: "Eres un asistente para agendar pedidos. Solicita información como nombre, fecha, hora, artículos, ubicación y dirección." }
        ],
        order: initialize_order
      }
    end
  end

  def initialize_order
    {
      name: nil,
      delivery_date: nil,
      delivery_time: nil,
      items: [],
      address: nil
    }
  end

  def update_order_from_extracted_data(order, extracted_data)
    order[:name] = extracted_data["nombre"] unless extracted_data["nombre"] == "Desconocido"
    order[:date] = extracted_data["fecha_entrega"] unless extracted_data["fecha_entrega"] == "Desconocido"
    order[:time] = extracted_data["hora_entrega"] unless extracted_data["hora_entrega"] == "Desconocido"
    order[:items] = extracted_data["articulos"] unless extracted_data["articulos"] == "Desconocido"
    order[:address] = extracted_data["direccion"] unless extracted_data["direccion"] == "Desconocido"
  end

  def save_order_to_db(order, phone)
    Order.create!(
      phone: phone,
      name: order[:name],
      date: Date.parse(order[:date]),
      time: Time.parse(order[:time]),
      items: order[:items].join(", "),
      address: order[:address],
      status: "pending"
    )
  end
end
