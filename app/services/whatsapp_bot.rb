class WhatsAppBot
  def self.generate_response_with_data_extraction(context, order)
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    base_prompt = <<~PROMPT
      Actúa como un asistente virtual amigable para agendar pedidos.
      Tu objetivo es guiar al usuario en el proceso de agendar un pedido y, al mismo tiempo, analizar la conversación completa para extraer los datos necesarios.

      Datos necesarios para el pedido:
      - Nombre completo
      - Fecha de entrega
      - Hora de entrega
      - Artículos solicitados
      - Dirección de entrega

      Si el usuario no ha proporcionado ningun dato, saluda y presentate como el asistente y empieza a solicitar la informacion requerida.
      Si el usuario no ha proporcionado toda la información, haz preguntas amigables para completar los datos.
      Cuando detectes que el usuario ha terminado y el pedido tiene todos los datos, responde confirmando que el pedido está listo para ser procesado.

      Aquí está la conversación hasta ahora:
    PROMPT

    conversation_context = context.map do |msg|
      "#{msg[:role] == 'user' ? 'Usuario' : 'Asistente'}: #{msg[:content]}"
    end.join("\n")

    json_prompt = <<~JSON_PROMPT
      Responde de manera amigable e incluye los datos extraídos en formato JSON al final de tu respuesta:
      {
        "nombre": "#{order[:name] || 'Desconocido'}",
        "fecha_entrega": "#{order[:delivery_date] || 'Desconocido'}",
        "hora_entrega": "#{order[:delivery_time] || 'Desconocido'}",
        "articulos": "#{order[:items] || 'Desconocido'}",
        "direccion": "#{order[:address] || 'Desconocido'}",
        "pedido_completo": #{order_complete?(order)}
      }
    JSON_PROMPT

    prompt = base_prompt + conversation_context + "\n\n" + json_prompt


    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [ { role: "user", content: prompt } ],
        max_tokens: 500,
        temperature: 0.7
      }
    )

    # Extrae el contenido del asistente
    assistant_message = response.dig("choices", 0, "message", "content")

    extracted_data = {}
    if assistant_message
      begin
        # Busca un bloque JSON dentro del texto devuelto
        json_match = assistant_message.match(/\{.*\}/m)
        if json_match
          extracted_data = JSON.parse(json_match[0])
          # Elimina el bloque JSON del mensaje del asistente
          assistant_message.sub!(json_match[0], "")
        end
      rescue JSON::ParserError => e
        Rails.logger.error("Error al parsear JSON: #{e.message}")
      end
    end

    {
      message: assistant_message || "Lo siento, no pude generar una respuesta adecuada.",
      extracted_data: extracted_data
    }
  rescue => e
    Rails.logger.error("Error al generar la respuesta: #{e.message}")
    {
      message: "Lo siento, hubo un problema al procesar tu solicitud. Intenta nuevamente.",
      extracted_data: {}
    }
  end

  def self.order_complete?(order)
    order[:name].present? &&
      order[:date].present? &&
      order[:time].present? &&
      order[:items].any? &&
      order[:address].present?
  end
end
