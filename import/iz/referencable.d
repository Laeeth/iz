module iz.referencable;

import std.stdio;
import iz.types;

public string typeString(T)()
{
    return typeid(T).toString;
}

version(unittest) class TestModuleScope{}

unittest
{
    class Foo{}
    assert( typeString!int == "int");
    assert( typeString!TestModuleScope == __MODULE__ ~ ".TestModuleScope" );
}

/**
 * interface for a class reference.
 */
interface izReferenced
{
    /// the ID, as set when added as reference.
    ulong refID();
    /// the type, as registered in the izReferenceMan ( typeString!typeof(this) )
    string refType();
}

/**
 * Associates an pointer (a reference) to an unique ID (ulong).
 */
private alias itemsById = void*[ulong];

/**
 * itemsById for a type (identified by a string).
 */
private alias refStore = itemsById[string];


/**
 * The Referencable manager associates a variable of a particular type to 
 * an unique identifier.
 * For example, in a setting file, it allows to store the unique identifier
 * associated to a class instance, rather than storing all its properties, as
 * the instance settings may be saved elsewhere.
 */
static class izReferenceMan
{
    private
    {
        static refStore fStore;
    }
    public
    {

// Helpers --------------------------------------------------------------------+

        /**
         * Indicates if a type is referenced.
         * Params:
         * RT = a referencable type
         * Returns:
         * true if the type is referenced otherwise false.
         */
        static bool isTypeStored(RT)()
        {
            return ((typeString!RT in fStore) !is null);
        }

        /**
         * Indicates if a variable is referenced.
         * Params:
         * RT = a referencable type. Optional, likely to be infered.
         * aReference = a pointer to a RT.
         * Returns:
         * true if the variable is referenced otherwise false.
         */
        static bool isReferenced(RT)(RT* aReference)
        {
            return (referenceID!RT(aReference) != 0UL);
        }
        
        /**
         * Empties the references and the types.
         */
        static void reset()
        {
            fStore = fStore.init;
        }
// -----------------------------------------------------------------------------
// Add stuff ------------------------------------------------------------------+

        /** 
         * References a type. This is a convenience function since
         * storeReference() automatically stores a type when needed.
         * Params:
         * RT = a type to reference.
         */
        static void storeType(RT)()
        {
            fStore[typeString!RT][0] = null;
        }

        /** 
         * Proposes an unique ID for a particular reference.
         * This is a convenience function which will not return the same values for each software cession.
         * A better user solution is to use the hash of an identifier chain (e.g the hash of "wizard.lefthand.magicwand")
         * Params:
         * RT = a referencable type. Optional, likely to be infered.
         * aReference = a pointer to a RT.
         * Returns:
         * the unique ulong value used to identify the reference.
         */
        static ulong getIDProposal(RT)(RT* aReference)
        {
            // already stored ? returns current ID
            ulong ID = referenceID(aReference);
            if (ID != 0) return ID;

            // not stored ? return 1
            if (!isTypeStored)
            {
                storeType!RT;
                return 1UL;
            }

            // try to get an available ID in the existing range
            for(ulong i = 0; i < fStore[typeString!RT].length; i++)
            {
                if (fStore[typeString!RT][i] == null)
                    return i-1;
            }

            // otherwise returns the next ID after the current range.
            for(ulong i = 0; i < ulong.max; i++)
            {
                if (i > fStore[typeString!RT].length)
                    return i-1;
            }

            assert(0, "izReferenceMan is full for this type");
        }

        /**
         * Tries to store a reference.
         * Params:
         * RT = the type of the reference.
         * aReference = a pointer to a RT
         * anID = the unique identifier for this reference.
         * Return:
         * true if the reference is added otherwise false.
         */
        static bool storeReference(RT)(RT* aReference, ulong anID)
        {
            if (anID == 0) return false;
            // what's already there ?
            auto curr = reference!RT(anID);
            if (curr == aReference) return true;
            if (curr != null) return false;
            //
            fStore[typeString!RT][anID] = aReference;
            return true;
        }
// -----------------------------------------------------------------------------
// Remove stuff ---------------------------------------------------------------+

        /**
         * Tries to remove a reference identified by its ID.
         * Return: returns the reference if it's found otherwise returns null.
         */
        static RT* removeReference(RT)(ulong anID)
        {
            auto result = reference!RT(anID);
            if (result) fStore[typeString!RT][anID] = null;
            return result;
        }

        /** 
         * Tries to remove a reference.
         * Params:
         * RT = the type of the reference. Optional, likely to be infered.
         * aReference = a pointer to the RT to be removed.
         */
        static void removeReference(RT)(RT* aReference)
        {
            if (auto id = referenceID!RT(aReference))
                fStore[typeString!RT][id] = null;
        }

// -----------------------------------------------------------------------------
// Query stuff ----------------------------------------------------------------+

        /**
         * Indicates if a variable is referenced.
         * Params:
         * RT = the type of the reference. Optional, likely to be infered.
         * aReference = a pointer to a RT.
         * Returns:
         * Returns an ulong different from 0 if the variable is referenced.
         * Returns 0 if the variable is not referenced.
         */
        static ulong referenceID(RT)(RT* aReference)
        {
            if (!isTypeStored!RT) return 0UL;
            foreach (k; fStore[typeString!RT].keys)
            {
                if (fStore[typeString!RT][k] == aReference)
                    return k;
            }
            return 0UL;
        }

        /**
         * Retrieves a reference.
         * Params:
         * RT = the type of the reference to retrieve.
         * anID = the unique identifier of the reference to retrieve.
         * Returns:
         * Returns null if the operation fails otherwise a pointer to a RT.
         */
        static RT* reference(RT)(ulong anID)
        {
            if (anID == 0) return null;
            if (!isTypeStored!RT) return null;
            return cast(RT*) fStore[typeString!RT].get(anID, null);
        }
// -----------------------------------------------------------------------------        
        
    }
}

unittest
{
    
    alias delegate1 = ubyte delegate(long param);
    alias delegate2 = short delegate(uint param);
    class Foo{int aMember;}

    assert( !izReferenceMan.isTypeStored!delegate1 );
    assert( !izReferenceMan.isTypeStored!delegate2 );
    assert( !izReferenceMan.isTypeStored!Foo );

    izReferenceMan.storeType!delegate1;
    izReferenceMan.storeType!delegate2;
    izReferenceMan.storeType!Foo;

    assert( izReferenceMan.isTypeStored!delegate1 );
    assert( izReferenceMan.isTypeStored!delegate2 );
    assert( izReferenceMan.isTypeStored!Foo );

    auto f1 = construct!Foo;
    auto f2 = construct!Foo;
    auto f3 = construct!Foo;
    scope(exit) destruct(f1,f2,f3);

    assert( !izReferenceMan.isReferenced(&f1) );
    assert( !izReferenceMan.isReferenced(&f2) );
    assert( !izReferenceMan.isReferenced(&f3) );

    assert( izReferenceMan.referenceID(&f1) == 0);
    assert( izReferenceMan.referenceID(&f2) == 0);
    assert( izReferenceMan.referenceID(&f3) == 0);

    izReferenceMan.storeReference( &f1, 10UL );
    izReferenceMan.storeReference( &f2, 15UL );
    izReferenceMan.storeReference( &f3, 20UL );

    assert( izReferenceMan.reference!Foo(10UL) == &f1);
    assert( izReferenceMan.reference!Foo(15UL) == &f2);
    assert( izReferenceMan.reference!Foo(20UL) == &f3);

    assert( izReferenceMan.referenceID(&f1) == 10UL);
    assert( izReferenceMan.referenceID(&f2) == 15UL);
    assert( izReferenceMan.referenceID(&f3) == 20UL);

    assert( izReferenceMan.isReferenced(&f1) );
    assert( izReferenceMan.isReferenced(&f2) );
    assert( izReferenceMan.isReferenced(&f3) );

    izReferenceMan.removeReference(&f1);
    izReferenceMan.removeReference(&f2);
    izReferenceMan.removeReference!Foo(20UL);

    assert( !izReferenceMan.isReferenced(&f1) );
    assert( !izReferenceMan.isReferenced(&f2) );
    assert( !izReferenceMan.isReferenced(&f3) );

    izReferenceMan.removeReference!Foo(10UL);
    izReferenceMan.removeReference(&f2);
    izReferenceMan.removeReference!Foo(20UL);
    
    izReferenceMan.reset;
    assert( !izReferenceMan.isTypeStored!Foo );
    
    izReferenceMan.storeReference( &f1, 10UL );
    assert( izReferenceMan.isTypeStored!Foo );
    

    writeln("izReferenceMan passed the tests");
}
