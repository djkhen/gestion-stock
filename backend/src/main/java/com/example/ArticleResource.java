package com.example;

import jakarta.transaction.Transactional;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.util.List;

/**
 * API REST CRUD sur les articles du catalogue de stock.
 *
 * Tous les endpoints sont sous /articles et échangent du JSON.
 * Conçue pour être consommée par le client Flutter (desktop) du MVP.
 *
 *  GET    /articles            liste (option ?q= pour rechercher)
 *  GET    /articles/{id}       détail
 *  POST   /articles            création (201)
 *  PUT    /articles/{id}       modification
 *  DELETE /articles/{id}       suppression (204)
 */
@Path("/articles")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ArticleResource {

    // GET /articles  -> liste tous les articles, ou filtre si ?q= fourni.
    // La recherche couvre la référence et la désignation (insensible à la casse).
    @GET
    public List<Article> liste(@QueryParam("q") String q) {
        if (q == null || q.isBlank()) {
            return Article.listAll();
        }
        String motif = "%" + q.toLowerCase() + "%";
        return Article.list(
                "lower(reference) like ?1 or lower(designation) like ?1", motif);
    }

    // GET /articles/{id}  -> un article précis
    @GET
    @Path("/{id}")
    public Article detail(@PathParam("id") Long id) {
        Article article = Article.findById(id);
        if (article == null) {
            throw new WebApplicationException("Article " + id + " introuvable", 404);
        }
        return article;
    }

    // POST /articles  -> crée un article
    @POST
    @Transactional
    public Response creer(Article article) {
        if (article.id != null) {
            throw new WebApplicationException("L'id ne doit pas être fourni à la création", 422);
        }
        valider(article);
        if (Article.count("reference", article.reference) > 0) {
            throw new WebApplicationException(
                    "La référence '" + article.reference + "' existe déjà", 409);
        }
        article.persist();
        return Response.status(Response.Status.CREATED).entity(article).build();
    }

    // PUT /articles/{id}  -> met à jour un article
    @PUT
    @Path("/{id}")
    @Transactional
    public Article modifier(@PathParam("id") Long id, Article data) {
        Article article = Article.findById(id);
        if (article == null) {
            throw new WebApplicationException("Article " + id + " introuvable", 404);
        }
        valider(data);
        // Référence unique : interdit de la dupliquer sur un AUTRE article.
        Article homonyme = Article.find("reference", data.reference).firstResult();
        if (homonyme != null && !homonyme.id.equals(id)) {
            throw new WebApplicationException(
                    "La référence '" + data.reference + "' existe déjà", 409);
        }
        article.reference = data.reference;
        article.designation = data.designation;
        article.description = data.description;
        article.unite = data.unite;
        article.quantiteStock = data.quantiteStock;
        article.seuilAlerte = data.seuilAlerte;
        article.prixUnitaire = data.prixUnitaire;
        return article;
    }

    // DELETE /articles/{id}  -> supprime un article
    @DELETE
    @Path("/{id}")
    @Transactional
    public Response supprimer(@PathParam("id") Long id) {
        boolean supprime = Article.deleteById(id);
        if (!supprime) {
            throw new WebApplicationException("Article " + id + " introuvable", 404);
        }
        return Response.noContent().build();
    }

    /** Règles métier minimales partagées entre création et modification. */
    private void valider(Article a) {
        if (a.reference == null || a.reference.isBlank()) {
            throw new WebApplicationException("La référence est obligatoire", 422);
        }
        if (a.designation == null || a.designation.isBlank()) {
            throw new WebApplicationException("La désignation est obligatoire", 422);
        }
        if (a.unite == null || a.unite.isBlank()) {
            a.unite = "piece";
        }
        if (a.quantiteStock < 0) {
            throw new WebApplicationException("La quantité en stock ne peut être négative", 422);
        }
        if (a.seuilAlerte < 0) {
            throw new WebApplicationException("Le seuil d'alerte ne peut être négatif", 422);
        }
        if (a.prixUnitaire < 0) {
            throw new WebApplicationException("Le prix unitaire ne peut être négatif", 422);
        }
    }
}
