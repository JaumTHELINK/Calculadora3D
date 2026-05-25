# Calculadora de Custos de Impressão 3D

Aplicativo mobile Android para precificação de peças impressas em 3D e controle financeiro do negócio. Desenvolvido com **Flutter/Dart**.

---

## Funcionalidades

### Calculadora de Custos
- Cálculo por material (PLA, PETG, ABS, TPU, ASA, Nylon, Resina e mais)
- Suporte a **multi-cor e multi-material** com pesos e custos individuais por filamento
- Tempo de impressão em horas decimais (ex: 3.8h)
- Custo de energia elétrica baseado na potência da impressora e tarifa kWh
- Mão de obra com valor por hora configurável
- Hardware, embalagem e materiais extras (argolas, parafusos, imãs etc.)
- Depreciação da impressora e impostos/IVA

### Precificação
- 4 faixas de preço sugerido: **Competitivo (25%)**, **Padrão (40%)**, **Premium (60%)** e **Luxo (80%)**
- Margem personalizada com slider e campo editável
- Integração com taxas das plataformas: **Shopee (20% + R$ 4,00/peça)**, **Mercado Livre (17%)**, **TikTok Shop (9%)** e **Revendedor (30%)**
- Simulador de **produção em lote** com custo total, receita e lucro por quantidade

### Histórico
- Salva cálculos realizados com data e hora
- Possibilidade de recarregar um cálculo salvo na calculadora
- Exclusão individual ou completa do histórico

### Módulo Financeiro
- Registro de **receitas** e **despesas** por categoria
- Vinculação de vendas ao histórico de cálculos
- Filtro por mês com navegação entre períodos
- Gráfico de barras de receitas vs despesas dos últimos 6 meses
- Resumo de despesas por categoria com barra proporcional
- Cálculo de **ROI da impressora**

### Estoque de Filamentos
- Cadastro de carretéis com marca, material, cor, peso e custo
- Barra visual de consumo por carretel
- Registro de uso por peça produzida com vínculo ao histórico
- Histórico de consumo por carretel com opção de desfazer

### Configurações
- Valores fixos salvos automaticamente (material padrão, custo/kg, potência, tarifa, valor/hora, embalagem, imposto)
- Taxas das plataformas de venda editáveis
- Backup automático no **Google Drive**

---

## Tecnologias utilizadas

- [Flutter](https://flutter.dev) / Dart
- [shared_preferences](https://pub.dev/packages/shared_preferences) — armazenamento local
- [fl_chart](https://pub.dev/packages/fl_chart) — gráficos
- [google_sign_in](https://pub.dev/packages/google_sign_in) — autenticação Google
- [googleapis](https://pub.dev/packages/googleapis) — integração com Google Drive

---

## Como rodar

```bash
flutter pub get
flutter run
```

Para gerar o APK:
```bash
flutter build apk --release
```

---
