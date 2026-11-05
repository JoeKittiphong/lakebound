"""Read-only HTTPS test of the installed legacy Web App compatibility bridge."""
import json
import urllib.request

URL='https://script.google.com/macros/s/AKfycbwP1Ui0jGty5aeR63o5dFf5G15zZQxnyrgiFRcgyHwcJ0b4hfgV3Kzwva_3ld7EmwZTdw/exec'
if __name__=='__main__':
    with urllib.request.urlopen(URL+'?scope=all&limit=10',timeout=45) as response:
        result=json.load(response)
    assert result.get('schema')==3 and isinstance(result.get('rows'),list),result
    print('LEGACY BRIDGE RESULT: schema 3, '+str(len(result['rows']))+' rows, version '+result['version'])
