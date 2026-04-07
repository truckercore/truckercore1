

# OwnerOpExpense


## Properties

| Name | Type | Description | Notes |
|------------ | ------------- | ------------- | -------------|
|**id** | **UUID** |  |  [optional] |
|**orgId** | **UUID** |  |  [optional] |
|**userId** | **UUID** |  |  [optional] |
|**loadId** | **UUID** |  |  [optional] |
|**category** | [**CategoryEnum**](#CategoryEnum) |  |  [optional] |
|**amountUsd** | **BigDecimal** |  |  [optional] |
|**miles** | **BigDecimal** |  |  [optional] |
|**notes** | **String** |  |  [optional] |
|**incurredOn** | **LocalDate** |  |  [optional] |
|**createdAt** | **OffsetDateTime** |  |  [optional] |



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



