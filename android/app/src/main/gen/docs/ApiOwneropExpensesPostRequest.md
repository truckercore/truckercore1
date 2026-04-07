

# ApiOwneropExpensesPostRequest


## Properties

| Name | Type | Description | Notes |
|------------ | ------------- | ------------- | -------------|
|**loadId** | **UUID** |  |  [optional] |
|**category** | [**CategoryEnum**](#CategoryEnum) |  |  |
|**amountUsd** | **BigDecimal** |  |  |
|**miles** | **BigDecimal** |  |  [optional] |
|**notes** | **String** |  |  [optional] |
|**incurredOn** | **LocalDate** |  |  |



## Enum: CategoryEnum

| Name | Value |
|---- | -----|
| FUEL | &quot;fuel&quot; |
| TOLLS | &quot;tolls&quot; |
| REPAIRS | &quot;repairs&quot; |
| TIRES | &quot;tires&quot; |
| INSURANCE | &quot;insurance&quot; |
| PERMITS | &quot;permits&quot; |
| PARKING | &quot;parking&quot; |
| DETENTION | &quot;detention&quot; |
| LUMPER | &quot;lumper&quot; |
| OTHER | &quot;other&quot; |



