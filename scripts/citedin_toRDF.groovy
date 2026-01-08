import groovy.yaml.YamlSlurper

fileContent = new File("./downstream/citedin_lookup.yml").text

def ys = new YamlSlurper()
def yaml = ys.parseText(fileContent)[0]

citoCites = "http://purl.org/spar/cito/cites"

yaml.keySet().each { pathway ->
  if (pathway.startsWith("WP")) {
    pwIRI = "https://identifiers.org/wikipathways/$pathway"
    yaml[pathway].each { link ->
      pub = link.link
      if (pub.startsWith("PMC")) {
        pubIRI = pub.replace("PMC", "https://europepmc.org/article/PMC/")
        println "<$pubIRI> <$citoCites> <$pwIRI> ."
      } else if (pub.startsWith("10.")) {
        pubIRI = "https://doi.org/" + pub
        println "<$pubIRI> <$citoCites> <$pwIRI> ."
      }
    }
  }
}
