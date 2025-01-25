class WhatsAppBot
  def self.generate_response(user_message, context = nil)
    # Uso de caché para evitar solicitudes repetidas a OpenAI
      client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
      begin
             # Llamada al modelo GPT-3.5 con el historial completo
             puts "CONTEXT: #{context}"
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
end
