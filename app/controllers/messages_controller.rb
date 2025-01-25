require 'twilio-ruby'
require 'openai'
require_relative '../services/whatsapp_bot' # Asegúrate de requerir el archivo whatsapp_bot.rb

class MessagesController < ApplicationController
def create
    if params['MessageType'] == 'text' && params['Body'].present? && params['From'].present?
        user_message = params['Body']
        from_number = params['From']
        user_phone = params["WaId"]
        
        # Simula el estado de la conversación
        conversation = find_or_create_conversation(from_number)
        response_message = handle_message(conversation, user_message)
        
        # Envía la respuesta al cliente
        MessageSender.send(to: from_number, body: response_message)
        render json: { status: 'success' }, status: :ok
    # Maneja otros tipos de solicitudes (como entregas o lecturas)
    elsif params['MessageStatus'].present?
        Rails.logger.info("Message status update: #{params['MessageStatus']}")
        head :ok
    else
        head :bad_request
    end
end

  private

  def handle_message(conversation, user_message)
    context = conversation[:context]
  
    # Agrega el nuevo mensaje del usuario al contexto
    context << { role: "user", content: user_message }
  
    # Genera la respuesta del bot
    response = WhatsAppBot.generate_response(user_message, context)
  
    # Agrega la respuesta del asistente al contexto
    context << { role: "assistant", content: response }
  
    # Guarda el contexto actualizado usando el número de teléfono como clave
    puts conversation[:id]
    Rails.cache.write(conversation[:id], conversation, expires_in: 30.minutes)
  
    response
  end  

  def find_or_create_conversation(phone)
    Rails.cache.fetch(phone, expires_in: 30.minutes) do
      {
        id: phone,
        context: [
          { role: "system", content: "Eres un asistente para agendar pedidos. Solicita información como nombre, fecha, hora, artículos, ubicación y dirección." }
        ]
      }
    end
  end  
end
