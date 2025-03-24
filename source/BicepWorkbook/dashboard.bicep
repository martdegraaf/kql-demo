param version string = utcNow('yyMMddHHmm')

var workbookDefinition = string(loadJsonContent('workbook.json'))
var location = resourceGroup().location

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid(resourceGroup().id, 'mart-workbook')
  location: location
  kind: 'shared'
  tags: {
    team: 'Avengers'
  }
  properties: {
    category: 'workbook'
    displayName: 'Cool workbook'
    description: 'Best workbook in history'
    serializedData: workbookDefinition
    version: version
    sourceId: resourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
  }
}
