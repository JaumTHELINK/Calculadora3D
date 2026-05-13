# 🖨️ Calculadora de Custos de Impressão 3D

Aplicativo Flutter para calcular custos e preços de peças impressas em 3D.

## ✨ Funcionalidades

- **Detalhes da peça**: Nome, material (PLA, PETG, ABS, TPU etc.), custo por kg e peso
- **Tempo de impressão**: Horas + minutos de impressão + tempo de mão de obra
- **Energia elétrica**: Potência da impressora × tarifa (R$/kWh)
- **Custos adicionais**: Hardware e embalagem
- **Configurações avançadas**: Depreciação de máquina e imposto/IVA
- **Preços sugeridos**: Competitivo (25%), Padrão (40%), Premium (60%), Luxo (80%) e margem personalizada
- **Discriminação de custos**: Gráfico visual de alocação de custos
- Suporte a **preços com e sem impostos**

## 🚀 Como usar

### Pré-requisitos

- Flutter SDK 3.10+ instalado
- Android Studio ou VS Code com extensão Flutter
- Dispositivo Android ou emulador

### Instalação

```bash
# 1. Extraia os arquivos do projeto
# 2. Entre na pasta do projeto
cd impressao3d_calc

# 3. Instale as dependências
flutter pub get

# 4. Execute no dispositivo/emulador
flutter run

# 5. Para gerar o APK
flutter build apk --release
```

O APK gerado estará em: `build/app/outputs/flutter-apk/app-release.apk`

## 📁 Estrutura do projeto

```
lib/
├── main.dart                    # Ponto de entrada
├── models/
│   └── calculator_model.dart    # Lógica de cálculos
├── screens/
│   └── calculator_screen.dart   # Tela principal
└── widgets/
    ├── section_card.dart        # Card de seção
    ├── input_field.dart         # Campo de entrada
    ├── price_card.dart          # Card de preço sugerido
    └── cost_breakdown.dart      # Discriminação de custos
```

## 🧮 Fórmulas usadas

- **Custo de material** = (peso em g / 1000) × custo por kg
- **Custo de energia** = (potência em W / 1000) × horas de impressão × tarifa kWh
- **Custo de mão de obra** = (minutos / 60) × valor da hora
- **Preço com margem** = custo total ÷ (1 - margem%)
- **Preço com imposto** = preço com margem × (1 + imposto%)
