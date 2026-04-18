# Tech Challenge - Objetivos da Fase 1

Analisamos a aplicação Toggle Master conforme solicitado e chegamos nos seguintes entendimentos:

## Entregáveis da Fase 1

1.  [**Vídeo de Demonstração (até 15 minutos):**](https://youtu.be/ylH_xMPFNNw)

2.  **Documentação Separada por Tópicos:**
- [Vantagens](#vantagens);
- [Desvantagens](#desvantagens);
- [Atende aos 12 Fatores](#-cobertura-dos-12-fatores);
- [Pontos de Melhoria](#pontos-de-melhoria);
- [Análise Ponto a Ponto dos 12 Fatores com Simbologia](#-legenda-dos-símbolos-utilizados-na-classificação);
- [Diagrama Link](https://excalidraw.com/#json=7f1MZc40Wjoz2eTTvR7dp,otmG3QofYMlNNVtNjaHMoA);
- [Diagrama Imagem](#diagrama-de-arquitetura-aplicada)
- [Calculadora](#calculadora-com-estimativa-de-preço);

3.  **Integrantes do Grupo**: 
- [Aline Estevo da Silva](www.linkedin.com/in/aline-estevo)
- [Thiago de Melo Macedo](#)
- [Jefferson Fernandes de Freitas](#)
- [Vinicius Jorge de Oliveira](#)
- [Maurício Magnago Castro Sá](#)

> **Importante:** Deixando uma observação de que não foi possível aplicar essa ação **Compreender e aplicar práticas básicas de segurança na AWS (IAM, Security Groups)** por falta de permissão no laboratório da AWS. 
>Fizemos um análise ponto a ponto nos 12 fatores sinalizando quais entendemos que atende 🆗, atende parcialmente 🔥 e não atende 👎.

## Vantagens

- Custo de provisionamento de banco dados e deploys.
- Simplicidade inicial de entendimento e desenvolvimento do código.

## Desvantagens

- Forte acoplamento e criticidade nas alterações; (qualquer atualização exige um novo deploy)
- Escalabilidade limitada;
- Conforme a evolução do código aumenta a complexidade de manutenção.

## Cobertura dos 12 Fatores

- Codebase: código versionado em Git
- Dependencies: gerenciamento via requirements.txt
- Config: utilização de variáveis de ambiente
- Processes: aplicação stateless
- Port Binding: aplicação exposta via porta HTTP

## Pontos de Melhoria

- Centralização de logs
- Implementação de pipeline CI/CD
- Melhor separação entre ambientes de desenvolvimento e produção
- Config permite configuração externa no ambiente docker, mas não está implementada no momento.
- O banco de dados deve ser tratado como um recurso externo e não acoplado ao código


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
Execute a aplicação como um ou mais processos que não armazenam estado 🆗
- **VII. Vínculo de porta**: 
Exporte serviços por ligação de porta 🆗
- **VIII. Concorrência**: 
Dimensione por um modelo de processo 👎
- **IX. Descartabilidade**: 
Maximizar a robustez com inicialização e desligamento rápido 🆗 Ajuste de robustes (autoscale, redundância)
- **X. Dev/prod semelhantes**
Mantenha o desenvolvimento, teste, produção o mais semelhante possível 🔥
- **XI. Logs**
Trate logs como fluxo de eventos 👎
- **XII. Processos de Admin**
Executar tarefas de administração/gerenciamento como processos pontuais 👎

## Calculadora com Estimativa de Preço

![](/.github/price-calculator.jpeg)

## Diagrama de Arquitetura Aplicada

![Diagrama Imagem](/.github/DiagramaArquiteturaAplicadaTechChallenge.png)
