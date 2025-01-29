class WhatsAppBot
  def self.generate_response(user_message, context = nil)
      # Uso de caché para evitar solicitudes repetidas a OpenAI
      client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
      begin
        # Llamada al modelo GPT-3.5 con el historial completo
        response = client.chat(
          parameters: {
            model: "gpt-3.5-turbo",
            messages: context,
            max_tokens: 150
          }
        )
        response.dig("choices", 0, "message", "content") || "Lo siento, no pude generar una respuesta."
      rescue Faraday::TooManyRequestsError
        attempts += 1
        if attempts <= 3
          sleep(2**attempts)
          retry
        else
          "Lo siento, el servicio está temporalmente no disponible. Por favor, intenta más tarde."
        end
      end
  end

  def self.extract_entities_from_message(user_message)
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    current_date = Date.today.strftime("%Y-%m-%d")

    prompt = <<~PROMPT
      Actúa como un extractor de datos para un sistema de pedidos.
      Analiza el siguiente mensaje y extrae la información relevante en formato JSON.
      Si no encuentras alguna información, usa null.

      Datos necesarios:
      - Nombre completo, es de tipo texto
      - Fecha de entrega, es de tipo date por lo cual debe ser en formato YYYY-MM-DD
      - Hora de entrega, es de tipo time por lo cual debe ser en formato HH:MM
      - Dirección de entrega, es tipo texto
      - Artículos solicitados, es tipo texto

      Hoy es: #{current_date}.
      Interpreta fechas relativas como "hoy", "mañana" o "el próximo lunes" en base a esta fecha.

      Mensaje del usuario: "#{user_message}"

      Responde en formato JSON:
      {
        "name": null,
        "delivery_date": null,
        "delivery_time": null,
        "items": null,
        "address": null
      }
    PROMPT


    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [ { role: "user", content: prompt } ],
        max_tokens: 150
      }
    )

    # Intenta parsear la respuesta JSON
    extracted_data = JSON.parse(response.dig("choices", 0, "message", "content")) rescue {}
    extracted_data
  end
end
