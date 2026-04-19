<div align="center">
  <br/>
  <hr style="border: none; border-top: 1px solid #ED145B; width: 100%; margin: 0 auto"/>
</div>

![/.github/LOGO-FIAP.png](/.github/LOGO-FIAP.png)

# Tech Challenge - Objetivos da Fase 1

Analisamos a aplicação Toggle Master conforme solicitado e chegamos nos seguintes entendimentos:

## Entregáveis da Fase 1

1. [**Vídeo de Demonstração (até 15 minutos):**](https://youtu.be/ylH_xMPFNNw)

2. **Documentação Separada por Tópicos:**

- [Análise do Monolito](#porque-aplicação-é-um-monolito);
- [Vantagens](#vantagens);
- [Desvantagens](#desvantagens);
- [Atende aos 12 Fatores](#cobertura-dos-12-fatores);
- [Pontos de Melhoria](#pontos-de-melhoria);
- [Análise Ponto a Ponto dos 12 Fatores com Simbologia](#legenda-dos-símbolos-utilizados-na-classificação);
- [Diagrama Link](https://excalidraw.com/#json=7f1MZc40Wjoz2eTTvR7dp,otmG3QofYMlNNVtNjaHMoA);
- [Diagrama Imagem](#diagrama-de-arquitetura-aplicada)
- [Calculadora](#calculadora-com-estimativa-de-preço);

1. **Integrantes do Grupo**:

- [Aline Estevo da Silva](https://www.linkedin.com/in/aline-estevo)
- [Thiago de Melo Macedo](https://www.linkedin.com/in/thiago-melo-macedo)
- [Jefferson Fernandes de Freitas](#)
- [Vinicius Jorge de Oliveira](#)
- [Maurício Magnago Castro Sá](https://www.linkedin.com/in/mcastrosa)

> **Importante:** Deixando uma observação de que não foi possível aplicar essa ação **Compreender e aplicar práticas básicas de segurança na AWS (IAM, Security Groups)** por falta de permissão no laboratório da AWS.
>Fizemos um análise ponto a ponto nos 12 fatores sinalizando quais entendemos que atende 🆗, atende parcialmente 🔥 e não atende 👎.

## Porque aplicação é um Monolito?

O ToggleMaster é considerado um monolito por concentrar toda a sua lógica de negócio, acesso a dados e exposição de API em uma única aplicação implantável, compartilhando a mesma base de código e banco de dados. A comunicação ocorre internamente dentro do mesmo processo, sem separação em serviços independentes.

## Vantagens

- Custo de provisionamento de banco dados e deploys.
- Simplicidade inicial de entendimento e desenvolvimento do código.

## Desvantagens

- Forte acoplamento e criticidade nas alterações; (qualquer atualização exige um novo deploy)
- Escalabilidade limitada;
- Conforme a evolução do código aumenta a complexidade de manutenção.

## Cobertura dos 12 Fatores

- **I Codebase:** O projeto possui estrutura de código única e organizada, compatível com versionamento Git.
- **II Dependencies:** O `requirements.txt` declara todas as dependências com versões fixadas `Flask==2.2.2`, `psycopg2-binary==2.9.5` etc.O Dockerfile as instala de forma isolada.
- **VII Port Binding:** A aplicação se expõe via Gunicorn na porta `5000` de forma autocontida, sem depender de servidor externo.

## Pontos de Melhoria

- **III Config:** A aplicação possui suporte ao uso de variáveis de ambiente, porém essa prática ainda não está plenamente aplicada em todos os cenários, especialmente fora do ambiente Docker.
- **IV Backing Services:** No `app.py`, as variáveis são lidas no nível do módulo (fora de qualquer função), o que significa que a conexão é configurada em tempo de importação, não em tempo de execução. Trocar o banco exige reinicialização.
O `docker-compose.yaml` define as credenciais em texto plano, sem uso de secrets ou referências externas.
- **V Build,Release, Run:** O `volumes: - .:/app` no `docker-compose.yaml` é a evidência mais clara: ele monta o código-fonte diretamente no container em runtime, colapsando as etapas de build e run em uma só. Não há artefato de build separado, nem etapa de release com configuração aplicada.
- **VI Processes:** 
    ```bash
    # ❌ Estado compartilhado em variáveis globais de módulo
    DB_HOST = os.getenv("DB_HOST")
    DB_NAME = os.getenv("DB_NAME")
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")

    ```
    Embora o Gunicorn em modo stateless seja adequado, essas variáveis globais e a função `init_db()` que altera estado no banco diretamente sugerem que a aplicação não é completamente share-nothing.
- **VIII Concurrency:** A aplicação atualmente executa em processo único, não explorando paralelismo por múltiplos workers, o que limita sua capacidade de atender requisições simultâneas em maior escala.
- **IX Disposability:** A aplicação apresenta inicialização rápida, porém ainda carece de mecanismos mais robustos para encerramento e liberação adequada de recursos.
- **X Dev/prod parity:** Melhor separação entre ambientes de desenvolvimento e produção respeitando o uso do mesmo conjunto de ferramentas e serviços sempre que possível.
- **XI Logs:** Os logs ainda não são tratados como fluxo contínuo de eventos, e não há integração com sistemas de observabilidade, como Amazon CloudWatch.
- **XII Admin Processes:** 
    ```bash
    # ❌ init-db deveria ser pontual, não automático no start
    flask init-db
    exec gunicorn ...
    ```
    O `flask init-db` é chamado como CLI command `(@app.cli.command)`, o que é a forma correta pelo `Fator XII`. O problema real é que ele é chamado automaticamente pelo `entrypoint.sh` toda vez que a aplicação sobe, em vez de ser um processo pontual e independente

## Legenda dos Símbolos Utilizados na Classificação

- **🆗 ATENDE:** atende totalmente.
- **🔥 ATENDE PARCIALMENTE:** precisa de ajustes e melhorias para atender totalmente.
- **👎 NÃO ATENDE:** não atende.

## Os 12 Fatores Sinalizados Conforme Entendimento do Grupo

- **I. Base de Código**:
Uma base de código com rastreamento utilizando controle de revisão, muitos deploys 🆗
- **II. Dependências**:
Declare e isole as dependências 🆗
- **III. Configurações**:
Armazene as configurações no ambiente 🔥
- **IV. Serviços de Apoio**:
Trate os serviços de apoio, como recursos ligados 👎
- **V. Construa, lance, execute**:
Separe estritamente os builds e execute em estágios 👎
- **VI. Processos**:
Execute a aplicação como um ou mais processos que não armazenam estado 🔥
- **VII. Vínculo de porta**:
Exporte serviços por ligação de porta 🆗
- **VIII. Concorrência**:
Dimensione por um modelo de processo 👎
- **IX. Descartabilidade**:
Maximizar a robustez com inicialização e desligamento rápido 🔥
- **X. Dev/prod semelhantes**
Mantenha o desenvolvimento, teste, produção o mais semelhante possível 🔥
- **XI. Logs**
Trate logs como fluxo de eventos 👎
- **XII. Processos de Admin**
Executar tarefas de administração/gerenciamento como processos pontuais 🔥

## Calculadora com Estimativa de Preço

![](/.github/price-calculator.jpeg)

## Diagrama de Arquitetura Aplicada

![Diagrama Imagem](/.github/DiagramaArquiteturaAplicadaTechChallenge.png)
