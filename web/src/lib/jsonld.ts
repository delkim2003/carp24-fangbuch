export function itemListLD(items: Array<{name: string, url: string, image?: string, description?: string}>) {
  return {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    'itemListElement': items.map((item, i) => ({
      '@type': 'ListItem',
      'position': i + 1,
      'name': item.name,
      'url': item.url,
      ...(item.image && { 'image': item.image }),
      ...(item.description && { 'description': item.description })
    }))
  };
}