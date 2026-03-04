# UV Risk Assessment System - MVVM Implementation Guide

## Overview
The new UV Risk Assessment system replaces the basic "Risk" text with a comprehensive, modular system that provides actionable guidance to users. Built using MVVM pattern for easy experimentation and modification.

## Components

### 1. Models (`UVRiskModels.swift`)
- **UVRiskLevel**: Risk categories from Minimal to Dangerous
- **SunProtectionGuidance**: Time-based recommendations for sunscreen, shade, and avoiding sun
- **MiseryIndex**: Combines UV, temperature, humidity, and wind into a comfort/danger scale
- **UVRiskDisplayModel**: Complete assessment combining all factors for UI display

### 2. ViewModel (`UVRiskViewModel.swift`)
- **UVRiskViewModel**: Handles all risk calculation logic
- Subscribes to weather data changes for real-time updates
- Calculates protection time ranges from hourly UV data
- Computes misery index with weighted factors
- Generates actionable recommendations and warnings

### 3. View Components (`UVRiskComponents.swift`)
Modular components that can be easily commented out:

- **RiskLevelView**: Displays risk level with emoji and description
- **SunProtectionTimesView**: Shows time ranges for protection actions
- **MiseryIndexView**: Visual misery index with progress bar
- **MiseryFactorsDetailView**: Expandable detail of contributing factors
- **OverallRecommendationView**: Primary guidance and critical warnings
- **CompactRiskSummaryView**: Alternative compact layout

### 4. Updated Forecast View (`UVForecastCardView.swift`)
- Integrates `UVRiskViewModel` with weather data
- Modular component layout for easy experimentation
- Fallback to original advice if risk assessment unavailable

## Experimentation Guide

### Commenting Out Components
Each component can be individually disabled by commenting out lines in `UVForecastCardView.swift`:

```swift
// Risk Level Component (Comment out to disable)
RiskLevelView(riskLevel: riskAssessment.riskLevel)

// Sun Protection Times Component (Comment out to disable)
SunProtectionTimesView(protectionGuidance: riskAssessment.protectionGuidance)

// Misery Index Component (Comment out to disable)  
MiseryIndexView(miseryIndex: riskAssessment.miseryIndex)

// Misery Factors Detail (Comment out to disable)
// MiseryFactorsDetailView(factors: riskAssessment.miseryIndex.factors)

// Overall Recommendation Component (Comment out to disable)
OverallRecommendationView(assessment: riskAssessment)
```

### Alternative Layouts
Switch between full and compact layouts:

```swift
// Full layout (default)
VStack(alignment: .leading, spacing: 16) {
    RiskLevelView(riskLevel: riskAssessment.riskLevel)
    SunProtectionTimesView(protectionGuidance: riskAssessment.protectionGuidance)
    // ... other components
}

// Compact layout (uncomment to use)
// CompactRiskSummaryView(assessment: riskAssessment)
```

## Key Features

### Risk Levels
- **Low** (UV 0-2): Minimal protection needed
- **Moderate** (UV 3-5): Stay in shade, wear protection
- **High** (UV 6-7): Protection required, avoid peak hours
- **Very High** (UV 8-10): Extra protection essential
- **Extreme** (UV 11+): Stay indoors, sunburn risk in under 5 minutes

### Protection Time Ranges
- **Sunscreen Required**: UV 3+ periods
- **Seek Shade**: UV 6+ periods  
- **Avoid Sun**: UV 12+ periods (extreme danger - sunburn in <5 min)
- **Active indicators**: Shows "NOW" for current time periods

### Misery Index
Combines multiple factors on 0-100 scale:
- **UV Index** (0-40 points): Primary factor
- **Temperature** (0-25 points): Heat stress contribution
- **Humidity** (0-20 points): Comfort impact
- **Wind Speed** (0-15 points): Cooling/heating effect

#### Misery Levels
- **Pleasant** (0-14): Ideal conditions
- **Comfortable** (15-29): Nice weather
- **Noticeable** (30-44): Some discomfort
- **Uncomfortable** (45-59): Challenging conditions
- **Oppressive** (60-74): Heat stress risk
- **Dangerous** (75-89): Health risk
- **Extreme** (90-100): Life-threatening

### Critical Warnings
- **UV 12+** or **Misery Extreme**: Danger warnings
- **UV 11+** + **Misery Dangerous**: Combined hazard warnings
- **Heat illness risk**: High misery level warnings

## Customization

### Adjusting Thresholds
Modify `RiskCalculationSettings` in `UVRiskViewModel.swift`:

```swift
private struct RiskCalculationSettings {
    let sunscreenThreshold = 3      // UV level for sunscreen requirement
    let shadeThreshold = 6          // UV level for shade requirement  
    let avoidSunThreshold = 12      // UV level for avoiding sun (extreme danger)
}
```

### Misery Index Weighting
Adjust scoring in calculation methods:
- `calculateUVMiseryScore()`: UV contribution
- `calculateTemperatureMiseryScore()`: Temperature impact
- `calculateHumidityMiseryScore()`: Humidity effect
- `calculateWindMiseryScore()`: Wind cooling/heating

### UI Styling
Modify colors and styling in individual component views within `UVRiskComponents.swift`.

## Data Flow
1. **WeatherViewModel** provides UV/weather data
2. **UVRiskViewModel** calculates comprehensive assessment
3. **UVRiskComponents** display modular UI elements
4. **UVForecastCardView** orchestrates the complete display

## Testing
Preview data is available in `UVRiskDisplayModel.preview` for design testing without live weather data.
