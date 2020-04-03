---
title: 'Saving One-To-Many abstract relations with Symfony REST'
createdAt: '2016-09-25 14:00'
excerpt: 'Hanging out with friends of symfony'
postedBy: codernr
tags:
    - PHP
    - Symfony
    - REST
    - FOSRestBundle
    - JMSSerializerBundle
---

I'm working on a Symfony REST project at my company as we speak, and I've come across an interesting problem when I tried to save a new entity and its related abstract entities using **request body converter**. The problem was that, when posting a JSON object to a REST controller with related one-to-many abstract entities, the **JMSSerializer** doesn't know how to deserialize those. Let's see an example!

I created a little sample Symfony project with **FOSRestBundle** and **JMSSerializerBundle** to demonstrate the situation. I have a `Person` entity that has multiple `Instrument` entities in a OneToMany relationship, but the `Instrument` itself is an abstract class with single table inheritance. It has two child types, `GuitarInstrument` and `DrumsInstrument`. Here are the classes:

```php
namespace AppBundle\Entity;

use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\ORM\Mapping as ORM;

/**
 * Person
 *
 * @ORM\Table(name="person")
 * @ORM\Entity()
 */
class Person
{
    /**
     * @var int
     *
     * @ORM\Column(name="id", type="integer")
     * @ORM\Id
     * @ORM\GeneratedValue(strategy="AUTO")
     */
    private $id;

    /**
     * @var string
     *
     * @ORM\Column(name="name", type="string", length=255)
     */
    private $name;

    /**
     * @var ArrayCollection
     *
     * @ORM\OneToMany(targetEntity="Instrument", mappedBy="person", cascade={"persist", "remove"})
     */
    private $instruments;
    
    // ... boring getters and setters
}

/**
 * Instrument
 *
 * @ORM\Entity()
 * @ORM\InheritanceType("SINGLE_TABLE")
 * @ORM\DiscriminatorColumn(name="type", type="string")
 * @ORM\DiscriminatorMap({
 *     "guitar"     = "GuitarInstrument",
 *     "drums"    = "DrumsInstrument"
 * })
 */
abstract class Instrument
{
    /**
     * @var int
     *
     * @ORM\Column(name="id", type="integer")
     * @ORM\Id
     * @ORM\GeneratedValue(strategy="AUTO")
     */
    protected $id;

    /**
     * @var string
     *
     * @ORM\Column(name="name", type="string", length=255)
     */
    protected $name;

    /**
     * @var Person
     *
     * @ORM\ManyToOne(targetEntity="Person", inversedBy="instruments")
     */
    protected $person;
    
    //...
}

/**
 * GuitarInstrument
 *
 * @ORM\Table(name="guitar_instrument")
 * @ORM\Entity()
 */
class GuitarInstrument extends Instrument
{
    /**
     * @var int
     *
     * @ORM\Column(name="strings", type="integer")
     */
    private $strings;
    
    // ...
}

/**
 * DrumsInstrument
 *
 * @ORM\Table(name="drums_instrument")
 * @ORM\Entity()
 */
class DrumsInstrument extends Instrument
{
    /**
     * @var string
     *
     * @ORM\Column(name="snare", type="string", length=255)
     */
    private $snare;
    
    // ...
}
```

> Notice the `cascade={"persist", "remove"}` parameter in the `Person`'s `$instruments` annotation, using this, when a `Person` object is persisted to database, the related `Instrument` objects are persisted too

Then I created a REST resource controller for my `Person` entity:

> If you need some information about how to set up a REST api with Symfony, you should [check out the documentation](http://symfony.com/doc/current/bundles/FOSRestBundle/index.html)

```php
namespace AppBundle\Controller;

use FOS\RestBundle\Routing\ClassResourceInterface;
use FOS\RestBundle\Controller\FOSRestController;
use FOS\RestBundle\Controller\Annotations as FOSRestBundleAnnotations;
use FOS\RestBundle\View\View;
use AppBundle\Entity\Person;
use Sensio\Bundle\FrameworkExtraBundle\Configuration\ParamConverter;
use Symfony\Component\HttpFoundation\Response;

/**
 * Class PersonsController
 * @package AppBundle\Controller
 *
 * @FOSRestBundleAnnotations\View()
 */
class PersonsController extends FOSRestController implements ClassResourceInterface
{
    public function cgetAction()
    {
        $em = $this->getDoctrine()->getManager();

        $users = $em->getRepository('AppBundle:Person')->findAll();

        return $users;
    }

    /**
     * @param Person $person
     * @return View
     * @internal param Person $person
     *
     * @FOSRestBundleAnnotations\Post("/persons")
     * @ParamConverter("person", converter="fos_rest.request_body")
     */
    public function postAction(Person $person)
    {
        $manager = $this->getDoctrine()->getManager();
        $manager->persist($person);
        $manager->flush();

        return View::create($person, Response::HTTP_CREATED);
    }
}
```

As you can see here, I made a `postAction` that gets a `Person` object as parameter, thaks to the `@ParamConverter` annotation. This means that I can send a POST request with a JSON body containing the `Person` object data I want to save, and the request body converter automatically deserializes it into a `Person` object.

So let's post a JSON person object to this controller:

```json
{
  	"name": "Dave Grohl",
  	"instruments": [
      	{
        	"type": "guitar",
          	"name": "Dave's incredibly kick-ass PRS",
          	"strings": 6
        },
      	{
          	"type": "drums",
          	"name": "Dave's incredibly kick-ass DW",
          	"snare": "DW 14x6.5"
        }
   	]
}
```

Posting this, we get a HTTP 400 error code with the message: *You must define a type for AppBundle\Entity\Person::$instruments.*

This is because we posted an `instruments` array in the JSON object with different types of objects (`GuitarInstrument`, `DrumsInstrument`). The **JMSSerializerBundle** can't figure out how to deserialize this array so we have to tell it explicitly by using the `@Type` annotation in the `Person` entity:

```php
use JMS\Serializer\Annotation as JMS;

// ...

	/**
     * @var ArrayCollection
     *
     * @ORM\OneToMany(targetEntity="Instrument", mappedBy="person", cascade={"persist", "remove"})
     * @JMS\Type("ArrayCollection<AppBundle\Entity\Instrument>")
     */
    private $instruments;
    
// ...

```

Using this one line solves our problem, and posting the previous JSON we get a HTTP 201 message with the created entities!

> You can check out th `@Type` annotation reference [here](http://jmsyst.com/libs/serializer/master/reference/annotations#type)