class WhatsAppBot
  def self.generate_response(user_message, context = nil)
    set_client
    attempts = 0
    begin
      response = @client.chat(
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
    set_client
    current_date = Date.today.strftime("%Y-%m-%d")

    # Obtener productos en stock y convertir a JSON para que OpenAI los use
    products = Product.where("stock > 0").select(:name, :price, :stock)
    product_data = products.map do |product|
      { name: product.name, price: product.price, stock: product.stock }
    end.to_json

    prompt = <<~PROMPT
      Actúa como un extractor de datos para un sistema de pedidos.
      Analiza el siguiente mensaje y extrae únicamente la información relevante en formato JSON.
      Si no encuentras alguna información, usa null.

      **Datos necesarios:**
      - Nombre completo (texto)
      - Fecha de entrega (YYYY-MM-DD)
      - Hora de entrega (HH:MM)
      - Dirección de entrega (texto)
      - Ubicación en Google Maps (si el usuario la comparte)
      - Artículos solicitados (texto)(nombre del producto y cantidad)

      **Condiciones:**
      - Solo permite pedidos de los siguientes productos (incluyendo stock disponible): #{product_data}
      - Si se solicita un producto que no existe, ignóralo y usa null.
      - Si el usuario pide más cantidad de la disponible, ignóralo y usa null.
      - Interpreta fechas relativas como "hoy", "mañana" o "el próximo lunes" basado en la fecha actual: #{current_date}.
      - Si el usuario comparte ubicación en WhatsApp, guárdala como 'location', 'latitude' y 'longitude'.

      **Ejemplo de respuesta esperada en JSON:**
      {
        "name": "Juan Pérez",
        "delivery_date": "2024-02-01",
        "delivery_time": "14:00",
        "items": "1 Pizza Hawaiana Mediana, 1 refresco de 2 litros",
        "address": "Calle 123, Ciudad"
        "location": "Calle 123, Ciudad, Municipo, Estado"
        "latitude": "20.577154380124"
        "longitude": "-98.62409637624"
      }

      **Mensaje del usuario:** "#{user_message}"

      Responde en formato JSON:
      {
        "name": null,
        "delivery_date": null,
        "delivery_time": null,
        "items": null,
        "address": null
        "location": null
        "latitude": null
        "longitude": null
      }
    PROMPT

    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [ { role: "user", content: prompt } ],
        max_tokens: 200
      }
    )

    extracted_data = JSON.parse(response.dig("choices", 0, "message", "content")) rescue {}
    extracted_data
  end

  private

  def self.set_client
    @client ||= OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  end
end
