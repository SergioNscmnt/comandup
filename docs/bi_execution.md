# BI Execution — ComandUp

## Objetivo
Implementar um dashboard administrativo com foco em pedidos, financeiro, lucratividade, sazonalidade e simulação de ofertas.

## Escopo Executado
1. Mapa de 7 abas: Visão Geral, Período, Horário x Dia, Modalidades, Financeiro, Produto/Lucratividade, Alertas.
2. Dicionário de métricas com fórmulas de pedidos, crescimento, ticket, tempos e resultado financeiro.
3. Matriz de metas por unidade com benchmark interno (P50/P75/P90) e score ponderado.
4. Modelo de elasticidade por produto (log-log + shrink por categoria).
5. Simulador de cenários de oferta (desconto, combo, frete grátis, reajuste).
6. Blueprint técnico SQL e DAX para implementação.

## Premissas de Dados (schema atual)
- Fatos: `orders`, `order_items`, `payments`.
- Dimensões: `products`, `categories`, `users` (até existir dimensão de unidade explícita).
- Modalidades: `orders.order_type` (`delivery`, `pickup`, `table`).
- Valores monetários em centavos (`*_cents`) com conversão para R$ na camada semântica.

## Backlog por Sprint

### Sprint 1 — Fundamentos de dados e camada semântica
Itens:
1. Criar views/marts analíticos (receita, descontos, ticket, pedidos concluídos/cancelados).
2. Criar tabela calendário e hierarquias de data.
3. Padronizar medidas centrais de Receita Líquida, Pedidos, Ticket, Cancelamento.
4. Publicar dataset inicial para dashboard executivo.

Critérios de aceite:
1. Valores de receita/pedidos batem com consultas SQL de conferência (diferença <= 0,5%).
2. Período diário/semanal/mensal funcionando sem quebra.
3. KPI de cancelamento consistente com status `canceled`.

### Sprint 2 — Financeiro e lucratividade por modalidade
Itens:
1. Construir aba Financeiro com waterfall e DRE gerencial.
2. Construir aba Modalidades com participação, ticket, cancelamento e margem.
3. Implementar alertas de margem negativa e cancelamento alto.

Critérios de aceite:
1. Waterfall fecha corretamente: bruta -> descontos -> líquida -> custos -> lucro.
2. Participação por modalidade soma 100% no período filtrado.
3. Alertas disparam com thresholds configuráveis.

### Sprint 3 — Produto, custos e simulador de oferta
Itens:
1. Criar estrutura de custos por produto (ingredientes, embalagem, perdas, taxa, mão de obra, rateio fixo).
2. Calcular lucro unitário e lucro total por produto.
3. Implementar simulador com cenários (desconto/combo/frete/reajuste).
4. Regras automáticas: produto herói/problema e margem mínima 25%.

Critérios de aceite:
1. Simulador retorna comparação baseline x cenário para receita, volume e lucro.
2. Produtos com margem <25% aparecem em alerta.
3. Ranking de produto herói/problema reflete lucro total e margem.

### Sprint 4 — Elasticidade, metas e operação contínua
Itens:
1. Estimar elasticidade por produto (log-log) com fallback por categoria.
2. Criar matriz de metas por unidade (benchmark interno).
3. Implementar score consolidado por unidade e faixas de performance.
4. Publicar painel de anomalias com trilha de investigação.

Critérios de aceite:
1. Elasticidade armazenada com nível de confiança (alta/média/baixa).
2. Metas `mínimo/alvo/excelência` geradas por percentis internos.
3. Score final por unidade disponível com histórico mensal.

## SQL base recomendado (resumo)
```sql
-- Receita líquida e pedidos concluídos por dia
SELECT
  DATE(o.created_at) AS dt,
  COUNT(*) FILTER_COND,
  SUM(o.total_cents)/100.0 AS receita_liquida
FROM orders o
WHERE o.status IN ('ready','delivered')
GROUP BY DATE(o.created_at);
```

Nota: em MariaDB, substituir `FILTER_COND` por `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` quando necessário.

## DAX base recomendado (resumo)
```DAX
Pedidos Concluidos =
CALCULATE(DISTINCTCOUNT(orders[id]), orders[status] IN {"ready","delivered"})

Receita Liquida = DIVIDE(SUM(orders[total_cents]),100)

Ticket Medio = DIVIDE([Receita Liquida],[Pedidos Concluidos])
```

## Riscos e lacunas atuais
1. Sem dimensão de unidade explícita no schema atual (benchmark por unidade depende de modelagem adicional de tenant/unidade).
2. CPV real depende de tabela de custo operacional ainda não persistida.
3. Elasticidade precisa de histórico de preço/volume consistente por produto.

