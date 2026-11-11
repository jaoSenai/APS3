

```mermaid
flowchart TB
    %% Definição das Pessoas (Atores)
    vendedora([👤 Industria Vendedora<br/><i>Publica sobras e anexa laudos</i>])
    moderador([👤 Moderador<br/><i>Aprova ou rejeita ofertas</i>])

    %% Limite do Sistema Central
    subgraph mkt [Marketplace B2B de Sobras]
        web["💻 Frontend Web<br/><i>Next.js 14 / React</i><br/><hr/>Formulario de oferta e upload de laudo"]
        api["⚙️ API de Catalogo<br/><i>Spring Boot 3 / Java 21</i><br/><hr/>OfertaController, OfertaService, ClassificacaoService"]
        worker["⚙️ Validador de Laudo<br/><i>Spring Boot 3 Worker</i><br/><hr/>Consome eventos e valida laudo/FDS"]
        broker[["📥 Broker de Eventos<br/><i>RabbitMQ 3.13</i><br/><hr/>Fila laudo.anexado"]]
        db[("🗄️ Banco Principal<br/><i>PostgreSQL 16 + PostGIS</i><br/><hr/>Ofertas, materiais, classificacoes")]
        storage[("📂 Armazenamento de Laudos<br/><i>MinIO (S3 compativel)</i><br/><hr/>PDFs de laudo e FDS")]
    end

    %% Sistemas Externos
    sinir["🏢 SINIR / MTR<br/><i>Sistema Externo</i><br/><hr/>Valida codigo IBAMA do residuo"]
    receita["🏢 API CNPJ<br/><i>Sistema Externo</i><br/><hr/>Regularidade da empresa"]

    %% Relacionamentos e Conexões
    vendedora -->|Usa / HTTPS| web
    moderador -->|Modera / HTTPS| web
    web -->|Chama / REST/JSON sobre HTTPS| api
    web -->|Envia laudo / HTTPS PUT URL pre-assinada| storage
    api -->|Le e grava / JDBC/SQL| db
    api -->|Valida codigo IBAMA / REST/HTTPS| sinir
    api -->|Consulta CNPJ / REST/HTTPS| receita
    api -->|Publica LaudoAnexadoEvent / AMQP 0-9-1| broker
    broker -->|Entrega evento / AMQP 0-9-1| worker
    worker -->|Le arquivo / S3 API/HTTPS| storage
    worker -->|Atualiza status da oferta / JDBC/SQL| db

    %% Estilização Padrão C4 Model (Cores)
    style vendedora fill:#08427B,stroke:#052E56,color:#FFF
    style moderador fill:#08427B,stroke:#052E56,color:#FFF
    
    style web fill:#1168BD,stroke:#0B4E8F,color:#FFF
    style api fill:#1168BD,stroke:#0B4E8F,color:#FFF
    style worker fill:#1168BD,stroke:#0B4E8F,color:#FFF
    style broker fill:#1168BD,stroke:#0B4E8F,color:#FFF
    style db fill:#1168BD,stroke:#0B4E8F,color:#FFF
    style storage fill:#1168BD,stroke:#0B4E8F,color:#FFF

    style sinir fill:#999999,stroke:#666666,color:#FFF
    style receita fill:#999999,stroke:#666666,color:#FFF
    
    style mkt fill:none,stroke:#B3B3B3,stroke-width:2px,stroke-dasharray: 5 5,color:#333
```
