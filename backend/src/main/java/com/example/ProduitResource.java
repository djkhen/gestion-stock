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
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.util.List;

/**
 * API REST exposant les opérations CRUD sur les produits.
 *
 * Tous les endpoints sont sous /produits et échangent du JSON.
 * Ces URL sont consommées indifféremment par Angular (web) et Flutter (mobile).
 */
@Path("/produits")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ProduitResource {

    // GET /produits  -> liste tous les produits
    @GET
    public List<Produit> liste() {
        return Produit.listAll();
    }

    // GET /produits/{id}  -> un produit précis
    @GET
    @Path("/{id}")
    public Produit detail(@PathParam("id") Long id) {
        Produit produit = Produit.findById(id);
        if (produit == null) {
            throw new WebApplicationException("Produit " + id + " introuvable", 404);
        }
        return produit;
    }

    // POST /produits  -> crée un produit
    @POST
    @Transactional
    public Response creer(Produit produit) {
        if (produit.id != null) {
            throw new WebApplicationException("L'id ne doit pas être fourni à la création", 422);
        }
        produit.persist();
        return Response.status(Response.Status.CREATED).entity(produit).build();
    }

    // PUT /produits/{id}  -> met à jour un produit
    @PUT
    @Path("/{id}")
    @Transactional
    public Produit modifier(@PathParam("id") Long id, Produit data) {
        Produit produit = Produit.findById(id);
        if (produit == null) {
            throw new WebApplicationException("Produit " + id + " introuvable", 404);
        }
        produit.nom = data.nom;
        produit.description = data.description;
        produit.prix = data.prix;
        return produit;
    }

    // DELETE /produits/{id}  -> supprime un produit
    @DELETE
    @Path("/{id}")
    @Transactional
    public Response supprimer(@PathParam("id") Long id) {
        boolean supprime = Produit.deleteById(id);
        if (!supprime) {
            throw new WebApplicationException("Produit " + id + " introuvable", 404);
        }
        return Response.noContent().build();
    }
}
