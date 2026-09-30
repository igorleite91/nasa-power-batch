# Registro de mudanças

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); o projeto
segue [versionamento semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

## [1.0.0] — 2026-09-30

Primeira versão pública, a partir do script `downlaod_nasa_power_estacoes.R` (fev/2025).

### Adicionado
- Validação da tabela de estações antes do download, com erro apontando a linha.
- Leitura de `.csv` além de `.xlsx`; datas em `aaaa-mm-dd`, `dd/mm/aaaa` ou do Excel.
- Novas tentativas automáticas (HTTP 429/5xx) e limite de 1 requisição/s.
- Cache por estação, com retomada de lotes interrompidos.
- Relatório `*_falhas.csv` com a mensagem de erro da API; o lote não para numa falha.
- Coluna `elevacao_m` (altitude da célula, informada pela API).
- Linha de comando com `--parametros`, `--comunidade`, `--cache`, `--sem-cache`.
- Testes offline com respostas reais da API, CI no Linux e Windows e `lintr`.

### Corrigido
- O valor de preenchimento `-999` da API era gravado como número e contaminava médias e
  somas; agora vira `NA`.

### Alterado
- Cada variável é alinhada pela data informada pela API, não pela posição na lista.
- Variáveis deixaram de ser fixas no código e passaram a ser configuráveis.
