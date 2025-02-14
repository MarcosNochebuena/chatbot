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

  def self.extract_entities_from_message(user_message, phone)
    set_client
    current_date = Date.today.strftime("%Y-%m-%d")

    # Obtener productos disponibles
    products = Product.where(available: true).select(:name, :price, :stock, :available)
    product_data = products.map { |p| { name: p.name, price: p.price, stock: p.stock, disponible: p.available } }.to_json

    # Obtener datos previos del usuario
    previous_conversation = Rails.cache.fetch(phone, expires_in: 30.minutes) || {}

    prompt = <<~PROMPT
      Actúa como un extractor de información para un sistema de pedidos.
      **Analiza el mensaje y extrae la información relevante en formato JSON.**

      - Nombre completo: texto
      - Fecha de entrega: YYYY-MM-DD
      - Hora de entrega: HH:MM
      - Dirección de entrega: texto
      - Ubicación en Google Maps (si la comparte)
      - Productos: Lista de productos válidos (cantidad y producto), asegurando que no excedan el stock y que este disponible disponible: texto

      **Lista de productos disponibles:** #{product_data}
      **Fecha actual:** #{current_date}

      **Historial del usuario:** #{previous_conversation.to_json}

      **Mensaje del usuario:** "#{user_message}"

      **Formato de respuesta esperado en JSON:**
      {
        "name": "Juan Pérez",
        "delivery_date": "2024-02-01",
        "delivery_time": "14:00",
        "items": "3 Pizzas Hawaianas Medianas, 1 refresco de 2 litros],
        "address": "Calle 123, Ciudad",
        "location": "Calle 123, Ciudad, Municipio, Estado",
        "latitude": "20.577154380124",
        "longitude": "-98.62409637624"
      }
    PROMPT

    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [ { role: "user", content: prompt } ],
        max_tokens: 250
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
