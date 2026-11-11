# APS 3 — Publicar Oferta de Sobra Industrial

Projeto: Marketplace B2B de Sobras Industriais (Grupo BTM)
Componente: Catálogo de Sobras
Funcionalidade crítica: Publicar oferta com classificação NBR 10004 e laudo/FDS para Classe I (UC03, UC04 e UC05)
Entidade principal: Oferta
Aluno: João Gabriel Portella

 1. Sobre a funcionalidade

Essa é basicamente a porta de entrada do marketplace. Se a indústria não consegue publicar a sobra dela direito, o resto do sistema nem tem o que mostrar. Só que não dá pra deixar qualquer um publicar qualquer coisa, porque resíduo industrial tem lei por trás (PNRS e NBR 10004). Por isso o fluxo tem três partes que se encaixam:

- UC03 – Publicar Oferta: a vendedora preenche os dados do lote (material, quantidade, preço ou permuta, frete CIF/FOB).
- UC04 – Classificar Resíduo (include): sempre acontece. O sistema enquadra o material na NBR 10004 (Classe I, IIA ou IIB) e confere o código IBAMA no SINIR.
- UC05 – Anexar Laudo e FDS (extend): só entra em ação se o resíduo for Classe I (perigoso). Aí o laudo e a FDS viram obrigatórios.

O ponto mais delicado é o laudo. Ele é um arquivo pesado e a validação dele demora, então é melhor processar essa parte de forma assíncrona, com fila de mensagens.

2. Operações públicas usadas (contrato com o Diagrama de Classes)

Pra manter a regra de consistência, toda mensagem do diagrama de sequência bate com uma operação desta lista:

| Classe / Interface | Operações públicas |
| --- | --- |
| OfertaController | + publicarOferta(dto: NovaOfertaDTO): OfertaCriadaDTO |
| OfertaService | + publicar(dto: NovaOfertaDTO, empresaId: Long): OfertaCriadaDTO |
| Empresa | + obterLicencaAtiva(): LicencaAmbiental |
| LicencaAmbiental | + isVigente(): Boolean |
| ClassificacaoService | + classificar(materialId: Long): ClassificacaoDTO |
| Material | + isResiduoPerigoso(): Boolean |
| SinirClient | + validarCodigoIbama(codigo: String): ResultadoIbamaDTO |
| LaudoStorage | + gerarUrlUpload(ofertaId: Long): UploadUrlDTO |
| Oferta | + anexarLaudo(url: String): Void · + enviarParaModeracao(): Void · + aprovar(): Void · + rejeitar(motivo: String): Void · + publicar(): Void · + pausar(): Void · + encerrar(): Void |
| EventBroker | + publicarEvento(evento: LaudoAnexadoEvent): Void |
| ValidadorLaudoWorker | + consumir(evento: LaudoAnexadoEvent): Void |
| NotificacaoService | + notificar(empresaId: Long, msg: String): Void |

## 3. Diagramas

### 3.1 Diagrama de Sequência
```mermaid
sequenceDiagram
    autonumber
    actor V as Vendedora
    participant FE as Frontend Web
    participant C as OfertaController
    participant S as OfertaService
    participant E as Empresa
    participant L as LicencaAmbiental
    participant CL as ClassificacaoService
    participant M as Material
    participant SN as SinirClient
    participant O as Oferta
    participant ST as LaudoStorage
    participant B as EventBroker
    participant W as ValidadorLaudoWorker
    participant N as NotificacaoService

    V->>FE: preencher formulario e confirmar
    FE->>C: publicarOferta(NovaOfertaDTO)
    C->>S: publicar(NovaOfertaDTO, empresaId)
    S->>E: obterLicencaAtiva()
    E-->>S: LicencaAmbiental
    S->>L: isVigente()
    L-->>S: Boolean

    alt licenca vencida
        S-->>C: ErroDTO(LICENCA_VENCIDA)
        C-->>FE: 422 ErroDTO
        FE-->>V: alerta de renovacao (redireciona UC01)
    else licenca vigente
        S->>CL: classificar(materialId)
        CL->>M: isResiduoPerigoso()
        M-->>CL: Boolean
        CL->>SN: validarCodigoIbama(codigo)
        SN-->>CL: ResultadoIbamaDTO
        CL-->>S: ClassificacaoDTO

        alt Classe I (perigoso)
            S->>ST: gerarUrlUpload(ofertaId)
            ST-->>S: UploadUrlDTO
            S-->>C: OfertaCriadaDTO(status=AGUARDANDO_LAUDO)
            C-->>FE: 201 OfertaCriadaDTO + UploadUrlDTO
            FE->>ST: upload laudo e FDS (URL pre-assinada)
            FE->>O: anexarLaudo(url)
            O-)B: publicarEvento(LaudoAnexadoEvent)
            B-)W: consumir(LaudoAnexadoEvent)
            W->>O: enviarParaModeracao()
            W-)N: notificar(empresaId, "laudo recebido")
        else Classe IIA ou IIB
            S->>O: enviarParaModeracao()
            S-->>C: OfertaCriadaDTO(status=AGUARDANDO_MODERACAO)
            C-->>FE: 201 OfertaCriadaDTO
            S-)N: notificar(empresaId, "oferta enviada")
        end
        FE-->>V: codigo unico do lote exibido
    end

```

### 3.2 Diagrama de Atividades com Raias
``` mermaid
flowchart TB
    subgraph R1["Raia 1 - Industria Vendedora"]
        A0((Inicio)) --> A1[Acessar Publicar Nova Oferta]
        A1 --> A2[Preencher material, quantidade, preco/permuta e frete]
        A2 --> A3[Confirmar envio]
        A9[Fazer upload de laudo e FDS]
        AR[Renovar licenca no UC01]
        AF((Fim))
    end

    subgraph R2["Raia 2 - Sistema Back-End"]
        B1{Licenca vigente?}
        B2[Classificar residuo NBR 10004]
        FORK[/"===== FORK ====="/]
        B3[Gerar miniaturas das fotos]
        B4[Indexar geolocalizacao PostGIS]
        JOIN[/"===== JOIN ====="/]
        B5{Classe do residuo?}
        B6[Gerar URL de upload]
        B7[Publicar evento LaudoAnexado]
        B8[Enviar oferta para moderacao]
        B9[Gerar codigo unico e notificar]
    end

    subgraph R3["Raia 3 - Servicos Externos"]
        C1[SINIR valida codigo IBAMA]
        C2[Worker valida laudo e FDS]
        C3{Laudo valido?}
    end

    A3 --> B1
    B1 -- "[licencaVigente == false]" --> AR --> AF
    B1 -- "[licencaVigente == true]" --> B2
    B2 --> FORK
    FORK --> C1
    FORK --> B3
    FORK --> B4
    C1 --> JOIN
    B3 --> JOIN
    B4 --> JOIN
    JOIN --> B5
    B5 -- "[classe == I]" --> B6 --> A9 --> B7 --> C2 --> C3
    B5 -- "[classe == IIA ou classe == IIB]" --> B8
    C3 -- "[laudoValido == true]" --> B8
    C3 -- "[laudoValido == false]" --> A9
    B8 --> B9 --> AF
```

### 3.3 Máquina de Estados da Oferta
``` mermaid
stateDiagram-v2
    [*] --> Rascunho

    Rascunho : entry / iniciarFormulario()
    Rascunho : exit / salvarDados()

    Rascunho --> Classificando : publicar() [licencaVigente] / classificarResiduo()
    Rascunho --> Bloqueada : publicar() [not licencaVigente] / alertarRenovacao()
    Bloqueada --> Rascunho : licencaRenovada

    Classificando : do / consultarSinir()
    Classificando --> AguardandoLaudo : classificado [classeI] / gerarUrlUpload()
    Classificando --> AguardandoModeracao : classificado [classeII] / enviarParaModeracao()

    AguardandoLaudo : entry / notificar("anexe laudo e FDS")
    AguardandoLaudo --> ValidandoLaudo : anexarLaudo(url) / publicarEvento()
    ValidandoLaudo --> AguardandoLaudo : laudoInvalido / notificar("laudo recusado")
    ValidandoLaudo --> AguardandoModeracao : laudoValido / enviarParaModeracao()

    AguardandoModeracao : entry / notificarModerador()
    AguardandoModeracao --> Ativa : aprovar() / indexarCatalogo()
    AguardandoModeracao --> Rejeitada : rejeitar(motivo) / notificarVendedora()

    state Ativa {
        [*] --> Disponivel
        Disponivel --> EmNegociacao : interesseAceito
        EmNegociacao --> Disponivel : negociacaoEncerrada [quantidade > 0]
    }
    Ativa : entry / exibirNoCatalogo()

    Ativa --> Pausada : pausar()
    Pausada --> Ativa : reativar() [licencaVigente]
    Ativa --> Concluida : loteVendido [quantidade == 0] / encerrar()
    Ativa --> Expirada : prazoVencido / removerDoCatalogo()

    Rejeitada --> [*]
    Concluida --> [*]
    Expirada --> [*]
```

### 3.4 C4 Nível 2 — Contêineres

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


### 3.5 ADR
### 3.5 ADR

Veja o documento detalhado em [docs/architecture/adr-0001.md](./docs/architecture/adr-0001.md).


## 4. Como os modelos conversam entre si

- A checagem de licença (`isVigente()`) aparece na sequência, vira o primeiro nó de decisão nas atividades e é a guarda `[licencaVigente]` na máquina de estados.
- O `alt` de Classe I na sequência é o mesmo desvio do diagrama de atividades e a mesma guarda `[classeI]` nos estados.
- O fork/join das atividades (validar IBAMA, gerar miniaturas das fotos e indexar geolocalização ao mesmo tempo) corresponde às chamadas paralelas e assíncronas da sequência.
- Uma oferta Classe I nunca vai direto pra `Ativa` sem passar por `AguardandoLaudo`. Isso impede que alguém publique resíduo perigoso sem documentação, ou seja, evita estado corrompido.
