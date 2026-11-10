@startuml C4_Container_PublicarOferta
!include [raw.githubusercontent.com](https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml)

title C4 Nivel 2 - Conteineres - Publicar Oferta (Marketplace B2B de Sobras)

Person(vendedora, "Industria Vendedora", "Publica sobras e anexa laudos")
Person(moderador, "Moderador", "Aprova ou rejeita ofertas")

System_Boundary(mkt, "Marketplace B2B de Sobras") {
    Container(web, "Frontend Web", "Next.js 14 / React", "Formulario de oferta e upload de laudo")
    Container(api, "API de Catalogo", "Spring Boot 3 / Java 21", "OfertaController, OfertaService, ClassificacaoService")
    Container(worker, "Validador de Laudo", "Spring Boot 3 Worker", "Consome eventos e valida laudo/FDS")
    ContainerQueue(broker, "Broker de Eventos", "RabbitMQ 3.13", "Fila laudo.anexado")
    ContainerDb(db, "Banco Principal", "PostgreSQL 16 + PostGIS", "Ofertas, materiais, classificacoes")
    ContainerDb(storage, "Armazenamento de Laudos", "MinIO (S3 compativel)", "PDFs de laudo e FDS")
}

System_Ext(sinir, "SINIR / MTR", "Valida codigo IBAMA do residuo")
System_Ext(receita, "API CNPJ", "Regularidade da empresa")

Rel(vendedora, web, "Usa", "HTTPS")
Rel(moderador, web, "Modera", "HTTPS")
Rel(web, api, "Chama", "REST/JSON sobre HTTPS")
Rel(web, storage, "Envia laudo", "HTTPS PUT URL pre-assinada")
Rel(api, db, "Le e grava", "JDBC/SQL")
Rel(api, sinir, "Valida codigo IBAMA", "REST/HTTPS")
Rel(api, receita, "Consulta CNPJ", "REST/HTTPS")
Rel(api, broker, "Publica LaudoAnexadoEvent", "AMQP 0-9-1")
Rel(broker, worker, "Entrega evento", "AMQP 0-9-1")
Rel(worker, storage, "Le arquivo", "S3 API/HTTPS")
Rel(worker, db, "Atualiza status da oferta", "JDBC/SQL")

@enduml
