class CacheWarmJob < ApplicationJob
  queue_as :default
  
  def perform(*args)
    @regioni = ["Marche",                                     
      "Lombardia",                                  
      "Piemonte",                                   
      "Liguria",                                    
      "Sicilia",                                    
      "Lazio",                                      
      "Campania",                                   
      "Basilicata",                                 
      "Abruzzo",                                    
      "Emilia-Romagna",                             
      "Puglia",                                     
      "Umbria",                                     
      "Toscana",                                    
      "Valle d'Aosta",                              
      "Friuli-Venezia Giulia",
      "Sardegna",
      "Molise",
      "Veneto",
      "Calabria",
      "Trentino-Alto Adige"]  

    @monuments = Monument.where(hidden: false)

    MonumentsController.expire_page("map")

    MonumentsController.cache_page(MonumentsController.renderer.new(ApplicationController.renderer.defaults).render(:map, assigns: {regioni: @regioni, monuments: @monuments} ), "map")
  end
end
