import os
import json
import boto3

DIST_ID = os.environ.get('CLOUDFRONT_DISTRIBUTION_ID', '')

def disable_cloudfront(dist_id):
    cf = boto3.client('cloudfront')
    resp = cf.get_distribution_config(Id=dist_id)
    etag = resp['ETag']
    config = resp['DistributionConfig']
    if not config['Enabled']:
        return 'CloudFront already disabled'
    config['Enabled'] = False
    cf.update_distribution(Id=dist_id, DistributionConfig=config, IfMatch=etag)
    return 'CloudFront disabled'

def handler(event, context):
    results = []
    if DIST_ID:
        try:
            results.append(disable_cloudfront(DIST_ID))
        except Exception as e:
            results.append('CloudFront ERROR: {}'.format(e))
    else:
        results.append('No distribution ID set')
    print(json.dumps(results))
    return {'results': results}

