# Como contribuir

Obrigado por querer melhorar o **nasa-power-batch**! Toda ajuda conta: relatar um erro,
sugerir uma variável, corrigir um erro de digitação no README ou implementar um item do
[roteiro](README.md#contribuindo).

*Contributions in English are welcome too.*

## Antes de começar

- **Encontrou um erro?** Abra uma [issue de erro](../../issues/new?template=erro.yml). Inclua a
  linha de comando usada, a mensagem completa e, se possível, uma tabela de estações mínima
  que reproduza o problema.
- **Tem uma ideia?** Abra uma [issue de sugestão](../../issues/new?template=sugestao.yml) antes de
  escrever muito código — assim a gente alinha o caminho e ninguém perde trabalho.
- **Dúvida de uso?** Use as [Discussions](../../discussions), se estiverem ativas, ou abra uma
  issue com a etiqueta `dúvida`.

## Preparando o ambiente

Você precisa do R ≥ 4.1.

```r
install.packages(c("httr2", "jsonlite", "readxl",       # execução
                   "testthat", "withr", "writexl",       # testes
                   "lintr"))                             # estilo
```

## Fluxo de trabalho

1. Faça um *fork* e crie um ramo descritivo: `git switch -c corrige-datas-excel`.
2. Faça a alteração. Mantenha as mudanças pequenas e focadas em um assunto.
3. **Adicione ou ajuste testes** em `tests/testthat/`. Os testes não podem depender de
   internet: se precisar de uma nova resposta da API, grave-a como JSON em
   `tests/testthat/fixtures/` e sirva-a com `httr2::local_mocked_responses()`, como nos
   testes existentes.
4. Rode, a partir da raiz do repositório:

   ```bash
   Rscript tests/testthat.R
   Rscript -e 'print(lintr::lint_dir("."))'
   ```

5. Abra o *pull request* preenchendo o modelo. A verificação automática (testes no Linux e no
   Windows + `lintr`) precisa passar.

## Convenções

- **Idioma:** código, comentários e mensagens em português, como no restante do repositório.
  Nomes de variáveis da POWER (`T2M`, `PRECTOTCORR`…) ficam como a API define.
- **Estilo:** [tidyverse style guide](https://style.tidyverse.org/), verificado pelo `lintr`
  com a configuração de [`.lintr`](.lintr). Funções e variáveis em `snake_case`, constantes em
  `MAIUSCULAS`.
- **Dependências:** mantenha o mínimo. Prefira R base; uma dependência nova precisa de um bom
  motivo no PR.
- **Compatibilidade:** não renomeie colunas da saída (`id_da_estacao`, `Date`, …) sem
  discussão prévia — há planilhas e rotinas que dependem delas.
- **Commits:** mensagem no imperativo, curta na primeira linha, explicando o *porquê* no corpo
  quando não for óbvio. Ex.: `Aceita datas dd/mm/aaaa vindas do Excel`.
- **Registro de mudanças:** descreva mudanças visíveis ao usuário em
  [`CHANGELOG.md`](CHANGELOG.md), na seção *Não lançado*.

## Boas maneiras com a API

A NASA POWER é um serviço público e gratuito. Não remova o limite de taxa nem o cache, e não
adicione testes que chamem a API real no CI.

## Código de conduta

Ao participar, você concorda em seguir o [Código de Conduta](CODE_OF_CONDUCT.md).
